import Foundation
import Security
import SwiftUI

final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isLoggedIn = false
    @Published var apiKey: String?
    @Published var username: String?
    
    private let service = "MyTube"
    private let account = "youtube_api_key"
    private let usernameAccount = "youtube_username"
    
    init() {
        loadCredentials()
    }
    
    func loadCredentials() {
        // Загружаем API ключ из Keychain
        if let key = loadFromKeychain(account: account) {
            apiKey = key
            isLoggedIn = true
        }
        
        // Загружаем имя пользователя
        if let name = loadFromKeychain(account: usernameAccount) {
            username = name
        }
    }
    
    func saveApiKey(_ key: String, username: String? = nil) -> Bool {
        guard !key.isEmpty else { return false }
        
        // Сохраняем API ключ
        let success = saveToKeychain(key, account: account)
        if success {
            apiKey = key
            isLoggedIn = true
            
            // Сохраняем имя пользователя если предоставлено
            if let username = username, !username.isEmpty {
                _ = saveToKeychain(username, account: usernameAccount)
                self.username = username
            }
        }
        return success
    }
    
    func logout() {
        _ = deleteFromKeychain(account: account)
        _ = deleteFromKeychain(account: usernameAccount)
        apiKey = nil
        username = nil
        isLoggedIn = false
    }
    
    // MARK: - Keychain операции
    
    private func saveToKeychain(_ value: String, account: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Сначала удаляем существующую запись
        _ = SecItemDelete(query as CFDictionary)
        
        // Добавляем новую
        var addItemQuery = query
        addItemQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        
        return SecItemAdd(addItemQuery as CFDictionary, nil) == errSecSuccess
    }
    
    private func loadFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        return nil
    }
    
    private func deleteFromKeychain(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

struct LoginView: View {
    @State private var apiKeyInput = ""
    @State private var usernameInput = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Вход в аккаунт")
                .font(.title2.bold())
            
            Text("Добавьте API ключ для доступа к комментариям и персонализированному контенту")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("API ключ (из приложения ПАРОЛИ)")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("API ключ", text: $apiKeyInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Имя пользователя (опционально)")
                    .font(.caption)
                    .foregroundColor(.gray)
                TextField("Имя пользователя", text: $usernameInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            HStack(spacing: 12) {
                Button("Отмена") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.gray)
                
                Spacer()
                
                Button("Сохранить") {
                    if AuthManager.shared.saveApiKey(apiKeyInput, username: usernameInput.isEmpty ? nil : usernameInput) {
                        dismiss()
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .disabled(apiKeyInput.isEmpty)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Как получить API ключ:")
                    .font(.caption.bold())
                
                Text("1. Откройте приложение «Пароли» на macOS")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("2. Найдите сохранённый пароль для YouTube")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("3. Скопируйте API ключ или токен доступа")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text("Или используйте ключ доступа из настроек Google Account")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
