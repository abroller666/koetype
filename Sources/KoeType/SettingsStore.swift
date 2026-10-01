import Foundation
import Security

/// APIキーは Keychain、その他の設定は UserDefaults に保存する。
final class SettingsStore {
    private static let keychainService = "com.maruko.koetype"
    private static let keychainAccount = "openai-api-key"

    var apiKey: String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func setAPIKey(_ key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
        ]
        SecItemDelete(base as CFDictionary)
        guard !key.isEmpty else { return }
        var attributes = base
        attributes[kSecValueData as String] = Data(key.utf8)
        SecItemAdd(attributes as CFDictionary, nil)
    }

    var transcriptionModel: String {
        get { UserDefaults.standard.string(forKey: "transcriptionModel") ?? "gpt-4o-transcribe" }
        set { UserDefaults.standard.set(newValue, forKey: "transcriptionModel") }
    }

    var cleanupModel: String {
        get { UserDefaults.standard.string(forKey: "cleanupModel") ?? "gpt-4o-mini" }
        set { UserDefaults.standard.set(newValue, forKey: "cleanupModel") }
    }
}
