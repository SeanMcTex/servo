import CoreGraphics
import Foundation
import FoundationModels
import Vision

enum OnDeviceError: LocalizedError {
    case modelUnavailable(SystemLanguageModel.Availability)
    case emptyResponse
    case visionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let availability):
            return "Apple Intelligence unavailable: \(availability)."
        case .emptyResponse:
            return "On-device model returned an empty response."
        case .visionFailed(let error):
            return "Vision text extraction failed: \(error.localizedDescription)"
        }
    }
}

struct OnDeviceClient {

    // Intentionally independent copy — same rules as OllamaClient.behaviorSystem.
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

    nonisolated func generate(
        personality: String,
        cgImage: CGImage,
        context: String? = nil
    ) async throws -> String {
        // 1. Check availability
        let availability = SystemLanguageModel.default.availability
        guard case .available = availability else {
            throw OnDeviceError.modelUnavailable(availability)
        }

        // 2. Extract visible text via Vision
        let visibleText = try await extractText(from: cgImage)
        print("[Servo] Vision extracted \(visibleText.split(separator: " ").count) words: \(visibleText.isEmpty ? "<none>" : visibleText)")

        // 3. Build prompt
        let contextBlock = context.flatMap { $0.isEmpty ? nil : "Activity context: \($0)\n\n" } ?? ""
        let textBlock = visibleText.isEmpty ? "" : "Visible text on screen: \(visibleText)\n\n"
        let userMessage = """
            \(contextBlock)\(textBlock)Character: \(personality)

            React to what you see on screen. One sentence only. Maximum 20 words. Stop after the first sentence ends.
            """
        print("[Servo] On-device request:\n  instructions: \(Self.behaviorSystem)\n  prompt: \(userMessage)")

        // 4. Generate response
        let session = LanguageModelSession(instructions: Self.behaviorSystem)
        let response = try await session.respond(to: userMessage)
        let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OnDeviceError.emptyResponse }
        print("[Servo] On-device response: \(trimmed)")
        print("----")
        return trimmed
    }

    // MARK: - Vision text extraction

    private func extractText(from cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: OnDeviceError.visionFailed(error))
                    return
                }
                let text = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OnDeviceError.visionFailed(error))
            }
        }
    }
}
