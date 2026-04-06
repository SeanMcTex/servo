import XCTest
@testable import Servo

final class OllamaClientPromptTests: XCTestCase {

    func testEmptyContextAndSamplesContainsOnlyRequestSection() {
        let result = OllamaClient.buildPrompt(personality: "test", contextItems: [], samples: [])
        XCTAssertTrue(result.contains("# Request"))
        XCTAssertFalse(result.contains("# Context"))
        XCTAssertFalse(result.contains("# Samples"))
    }

    func testContextItemsProduceContextSection() {
        let result = OllamaClient.buildPrompt(
            personality: "test",
            contextItems: ["Battery: 80%", "App: Xcode"]
        )
        XCTAssertTrue(result.contains("# Context"))
        XCTAssertTrue(result.contains("- Battery: 80%"))
        XCTAssertTrue(result.contains("- App: Xcode"))
    }

    func testSamplesProduceSamplesSection() {
        let result = OllamaClient.buildPrompt(
            personality: "test",
            contextItems: [],
            samples: ["You seem busy.", "Nice work!"]
        )
        XCTAssertTrue(result.contains("# Samples"))
        XCTAssertTrue(result.contains("# Request"))
    }

    func testBothSectionsPresent() {
        let result = OllamaClient.buildPrompt(
            personality: "test",
            contextItems: ["Time: morning"],
            samples: ["Looking good."]
        )
        XCTAssertTrue(result.contains("# Context"))
        XCTAssertTrue(result.contains("# Samples"))
        XCTAssertTrue(result.contains("# Request"))
    }

    func testMaxFiveSamplesPicked() {
        let manySamples = (1...10).map { "Sample \($0)" }
        let result = OllamaClient.buildPrompt(
            personality: "test",
            contextItems: [],
            samples: manySamples
        )
        // Count bullet lines in the Samples section
        let bulletCount = result
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("- Sample") }
            .count
        XCTAssertLessThanOrEqual(bulletCount, 5)
    }

    func testPersonalityAppearsInRequestSection() {
        let personality = "A grumpy wizard"
        let result = OllamaClient.buildPrompt(personality: personality, contextItems: [])
        XCTAssertTrue(result.contains(personality))
    }

    func testSectionOrder() throws {
        let result = OllamaClient.buildPrompt(
            personality: "test",
            contextItems: ["item"],
            samples: ["sample"]
        )
        let contextIdx = try XCTUnwrap(result.range(of: "# Context")).lowerBound
        let samplesIdx = try XCTUnwrap(result.range(of: "# Samples")).lowerBound
        let requestIdx = try XCTUnwrap(result.range(of: "# Request")).lowerBound
        XCTAssertLessThan(contextIdx, samplesIdx)
        XCTAssertLessThan(samplesIdx, requestIdx)
    }
}
