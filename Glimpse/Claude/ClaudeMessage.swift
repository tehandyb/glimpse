import Foundation

// MARK: - Request

struct ClaudeRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case system
        case messages
    }

    struct Message: Encodable {
        let role: String
        let content: [ContentBlock]
    }

    enum ContentBlock: Encodable {
        case text(String)
        case image(mediaType: String, base64: String)

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .image(let mediaType, let base64):
                try container.encode("image", forKey: .type)
                let source = ImageSource(type: "base64", mediaType: mediaType, data: base64)
                try container.encode(source, forKey: .source)
            }
        }

        enum CodingKeys: String, CodingKey {
            case type, text, source
        }

        struct ImageSource: Encodable {
            let type: String
            let mediaType: String
            let data: String

            enum CodingKeys: String, CodingKey {
                case type
                case mediaType = "media_type"
                case data
            }
        }
    }
}

// MARK: - Response

struct ClaudeResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }

    var firstText: String? {
        content.first(where: { $0.type == "text" })?.text
    }
}

// MARK: - Error

struct ClaudeErrorResponse: Decodable {
    let error: ErrorDetail

    struct ErrorDetail: Decodable {
        let type: String
        let message: String
    }
}
