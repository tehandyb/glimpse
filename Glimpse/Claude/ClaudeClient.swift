import Foundation

enum ClaudeModel: String, CaseIterable {
    case haiku = "claude-haiku-4-5-20251001"
    case sonnet = "claude-sonnet-4-6"

    var displayName: String {
        switch self {
        case .haiku: return "Haiku (fast)"
        case .sonnet: return "Sonnet (smart)"
        }
    }
}

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case apiError(String)
    case noResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Anthropic API key not set. Open Settings."
        case .apiError(let msg): return "Claude error: \(msg)"
        case .noResponse: return "Claude returned an empty response."
        }
    }
}

final class ClaudeClient {

    static let shared = ClaudeClient()

    var model: ClaudeModel = .haiku

    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private let apiVersion = "2023-06-01"

    private let systemPrompt = """
    You are a voice assistant running on smart glasses. The user is speaking to you hands-free.
    You can see what the user sees through the glasses camera.

    Rules:
    - Respond concisely. Your answers are spoken aloud — 1 to 3 sentences unless more is clearly needed.
    - If you see an image, use it to inform your answer. Don't narrate that you see an image.
    - Never say "As an AI" or similar disclaimers.
    - Be direct and helpful like a knowledgeable friend, not a customer service bot.
    """

    // MARK: - Main

    /// Send a voice query + optional camera frame to Claude. Returns Claude's text response.
    func query(text: String, frame: Data?) async throws -> String {
        guard let apiKey = apiKey else { throw ClaudeError.missingAPIKey }

        var contentBlocks: [ClaudeRequest.ContentBlock] = []

        // Attach camera frame if available
        if let frame {
            contentBlocks.append(.image(mediaType: "image/jpeg", base64: frame.base64EncodedString()))
        }

        contentBlocks.append(.text(text))

        let request = ClaudeRequest(
            model: model.rawValue,
            maxTokens: 300,
            system: systemPrompt,
            messages: [
                ClaudeRequest.Message(role: "user", content: contentBlocks)
            ]
        )

        let response = try await send(request: request, apiKey: apiKey)

        guard let text = response.firstText, !text.isEmpty else {
            throw ClaudeError.noResponse
        }

        return text
    }

    // MARK: - HTTP

    private func send(request: ClaudeRequest, apiKey: String) async throws -> ClaudeResponse {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            if let errorResponse = try? JSONDecoder().decode(ClaudeErrorResponse.self, from: data) {
                throw ClaudeError.apiError(errorResponse.error.message)
            }
            throw ClaudeError.apiError("HTTP \(httpResponse.statusCode)")
        }

        return try JSONDecoder().decode(ClaudeResponse.self, from: data)
    }

    // MARK: - API Key (Keychain)

    private let keychainKey = "co.glimpse.anthropic-api-key"

    var apiKey: String? {
        get {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: keychainKey,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess, let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        }
        set {
            // Delete existing
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: keychainKey
            ]
            SecItemDelete(deleteQuery as CFDictionary)

            guard let value = newValue, let data = value.data(using: .utf8) else { return }

            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: keychainKey,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            ]
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }
}
