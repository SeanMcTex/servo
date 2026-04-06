import Foundation

enum OllamaError: LocalizedError {
    case serverNotRunning
    case emptyResponse
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .serverNotRunning: "Ollama isn't running. Start it and try again."
        case .emptyResponse:    "Got an empty response from Ollama."
        case .badResponse(let code): "Ollama returned HTTP \(code)."
        }
    }
}

struct OllamaClient {

    // Hardcoded behavioral rules — never user-editable.
    // The user's personality definition is injected per-request into the prompt field.
    private static let behaviorSystem = """
        You observe the user's screen and react in character. Rules: \
        focus on what is visible on screen right now; never describe content neutrally; \
        the provided context (time, battery, thermals, etc.) describes the machine \
        on which you are running — not any person the user may be communicating with; \
        use context only when it adds something genuinely interesting — never mention \
        the time or day as filler; respond in ONE short sentence only, \
        STRICT MAXIMUM 20 words — stop writing the moment the sentence ends, \
        do not begin a second sentence.
        """

    // MARK: - Generate utterance from a screenshot

    nonisolated func generate(
        baseURL: String,
        model: String,
        personality: String,
        imageData: Data,
        contextItems: [String] = [],
        samples: [String] = []
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/chat") else {
            throw OllamaError.serverNotRunning
        }

        let base64Image = imageData.base64EncodedString()
        let userMessage = Self.buildPrompt(personality: personality, contextItems: contextItems, samples: samples)

        let messages: [[String: Any]] = [
            ["role": "system", "content": Self.behaviorSystem],
            ["role": "user",   "content": userMessage, "images": [base64Image]]
        ]

        let body: [String: Any] = [
            "model":    model,
            "messages": messages,
            "stream":   false,
            "think":    false,
            "options": [
                "temperature": 0.9,
                "num_predict": 80
            ]
        ]

        // Log the request minus the image payload
        let loggableMessages: [[String: Any]] = [
            ["role": "system", "content": Self.behaviorSystem],
            ["role": "user",   "content": userMessage, "images": ["<\(imageData.count / 1024)KB image omitted>"]]
        ]
        let loggableBody: [String: Any] = ["model": model, "messages": loggableMessages, "stream": false]
        if let loggableData = try? JSONSerialization.data(withJSONObject: loggableBody, options: .prettyPrinted),
           let loggableString = String(data: loggableData, encoding: .utf8) {
            print("[Servo] Ollama request:\n\(loggableString)")
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw OllamaError.badResponse(httpResponse.statusCode)
        }

        if let rawString = String(data: data, encoding: .utf8) {
            print("[Servo] Ollama raw response:\n\(rawString)")
        }

        struct ChatResponse: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let trimmed = decoded.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OllamaError.emptyResponse }
        print("[Servo] Ollama response: \(trimmed)")
        print("----")
        return trimmed
    }

    // MARK: - Prompt builder

    nonisolated static func buildPrompt(
        personality: String,
        contextItems: [String],
        samples: [String] = []
    ) -> String {
        var sections: [String] = []

        if !contextItems.isEmpty {
            let bullets = contextItems.map { "- \($0)" }.joined(separator: "\n")
            sections.append("# Context\n\(bullets)")
        }

        if !samples.isEmpty {
            let picked = samples.shuffled().prefix(5)
            let lines = picked.map { "- \($0)" }.joined(separator: "\n")
            sections.append("# Samples\n\(lines)")
        }

        sections.append("# Request\nCharacter: \(personality)\n\nReact to what you see on screen. One sentence only. Maximum 20 words. Stop after the first sentence ends.")

        return sections.joined(separator: "\n\n")
    }

    // MARK: - Check connection, return installed model names

    nonisolated func checkConnection(baseURL: String) async throws -> [String] {
        guard let url = URL(string: "\(baseURL)/api/tags") else {
            throw OllamaError.serverNotRunning
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw OllamaError.badResponse(httpResponse.statusCode)
        }

        struct Model: Decodable { let name: String }
        struct TagsResponse: Decodable { let models: [Model] }
        let decoded = try JSONDecoder().decode(TagsResponse.self, from: data)
        return decoded.models.map(\.name)
    }
}

// MARK: - URLError helpers

extension URLError {
    var isConnectionRefused: Bool {
        code == .cannotConnectToHost || code == .networkConnectionLost || code == .notConnectedToInternet
    }
}
