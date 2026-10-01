import AVFoundation

/// マイク入力を 16kHz mono 16bit の WAV 一時ファイルに録音する。
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var file: AVAudioFile?
    private var converter: AVAudioConverter?
    private var fileURL: URL?
    private var maxTimer: Timer?

    /// 上限(5分)に達したときに呼ばれる。AppDelegate が停止処理につなぐ。
    var onMaxDurationReached: (() -> Void)?

    private static let maxDuration: TimeInterval = 300
    private static let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                                    sampleRate: 16_000,
                                                    channels: 1,
                                                    interleaved: true)!

    func start() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("koetype-\(UUID().uuidString).wav")
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw KoeTypeError.noInputDevice
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: Self.targetFormat) else {
            throw KoeTypeError.audioConversionFailed
        }
        let file = try AVAudioFile(forWriting: url,
                                   settings: Self.targetFormat.settings,
                                   commonFormat: .pcmFormatInt16,
                                   interleaved: true)
        self.converter = converter
        self.file = file
        self.fileURL = url

        let ratio = Self.targetFormat.sampleRate / inputFormat.sampleRate
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let converter = self.converter, let file = self.file else { return }
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
            guard let output = AVAudioPCMBuffer(pcmFormat: Self.targetFormat, frameCapacity: capacity) else { return }
            var provided = false
            var conversionError: NSError?
            let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
                if provided {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                provided = true
                outStatus.pointee = .haveData
                return buffer
            }
            if status != .error, output.frameLength > 0 {
                try? file.write(from: output)
            }
        }
        engine.prepare()
        try engine.start()

        maxTimer = Timer.scheduledTimer(withTimeInterval: Self.maxDuration, repeats: false) { [weak self] _ in
            self?.onMaxDurationReached?()
        }
    }

    /// 録音を停止して WAV ファイルの URL を返す。録音していなければ nil。
    func stop() -> URL? {
        maxTimer?.invalidate()
        maxTimer = nil
        guard file != nil else { return nil }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let url = fileURL
        file = nil
        converter = nil
        fileURL = nil
        return url
    }

    func cancel() {
        if let url = stop() {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
