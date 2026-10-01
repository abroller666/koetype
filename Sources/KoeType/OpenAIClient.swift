import Foundation

enum KoeTypeError: LocalizedError {
    case noInputDevice
    case audioConversionFailed
    case invalidResponse
    case api(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "マイク入力デバイスが見つかりません。"
        case .audioConversionFailed:
            return "音声フォーマットの変換に失敗しました。"
        case .invalidResponse:
            return "APIから不正な応答が返されました。"
        case .api(let status, let message):
            return "APIエラー(\(status)): \(message)"
        }
    }
}

enum OpenAIAPI {
    static let baseURL = URL(string: "https://api.openai.com/v1")!

    static func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw KoeTypeError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            struct ErrorEnvelope: Decodable {
                struct APIError: Decodable { let message: String }
                let error: APIError
            }
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.message
                ?? String(data: data.prefix(500), encoding: .utf8) ?? "詳細不明"
            throw KoeTypeError.api(status: http.statusCode, message: message)
        }
    }
}

/// OpenAI の文字起こしAPI (POST /v1/audio/transcriptions)
struct TranscriptionService {
    let apiKey: String
    let model: String

    func transcribe(fileURL: URL, language: String = "ja") async throws -> String {
        var request = URLRequest(url: OpenAIAPI.baseURL.appendingPathComponent("audio/transcriptions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(name: String, value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        appendField(name: "model", value: model)
        appendField(name: "language", value: language)
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8))
        body.append(try Data(contentsOf: fileURL))
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        try OpenAIAPI.checkResponse(response, data: data)

        struct TranscriptionResponse: Decodable { let text: String }
        return try JSONDecoder().decode(TranscriptionResponse.self, from: data).text
    }
}

/// LLM によるフィラー除去・整形 (POST /v1/chat/completions)
struct CleanupService {
    let apiKey: String
    let model: String

    private static let systemPrompt = """
    あなたは日本語音声入力の整形エンジンです。音声認識で得られた文字起こしテキストを、次のルールで整形してください。

    - 「えーと」「えー」「あのー」「その(指示語でない場合)」「なんか」「まあ」「こう」「うーん」などのフィラー(言いよどみ)を除去する
    - 言い直しや繰り返しは最終的な発言内容に統合する(例:「明日、いや明後日に」→「明後日に」)
    - 句読点を自然に付与し、読みやすく整える
    - 「ですます調」「である調」など話者の語調は変えない
    - 内容の追加・要約・翻訳・意訳は一切しない。話された内容を忠実に保つ
    - 出力は整形後のテキストのみ。前置き、説明、引用符、コードブロックは付けない
    - フィラーや無意味な音のみで、意味のある内容がない場合は何も出力しない(空文字)
    """

    func clean(_ text: String) async throws -> String {
        var request = URLRequest(url: OpenAIAPI.baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "model": model,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": Self.systemPrompt],
                ["role": "user", "content": text],
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        try OpenAIAPI.checkResponse(response, data: data)

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }
}
