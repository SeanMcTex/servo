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

    // MARK: - Generate utterance from a screenshot

    nonisolated func generate(
        baseURL: String,
        model: String,
        systemPrompt: String,
        imageData: Data
    ) async throws -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.serverNotRunning
        }

        let base64Image = imageData.base64EncodedString()

        // Leading with the character instruction in the prompt (not just system) improves
        // compliance on smaller vision models that under-weight the system field.
        let characterPrompt = """
            \(systemPrompt)

            Now react to this screenshot. Do NOT write a neutral description. \
            Respond in character only. One or two sentences, max 25 words.
            """

        let body: [String: Any] = [
            "model":   model,
            "prompt":  characterPrompt,
            "images":  [base64Image],
            "stream":  false,
            "options": [
                "temperature": 0.9,
                "num_predict": 80
            ]
        ]

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw OllamaError.badResponse(httpResponse.statusCode)
        }

        struct GenerateResponse: Decodable { let response: String }
        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        let trimmed = decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OllamaError.emptyResponse }
        return trimmed
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
