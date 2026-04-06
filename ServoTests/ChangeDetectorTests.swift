import XCTest
import CoreGraphics
@testable import Servo

final class ChangeDetectorTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a solid-color CGImage of the given size.
    private func makeImage(width: Int = 64, height: Int = 64,
                           red: UInt8, green: UInt8, blue: UInt8) throws -> CGImage {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 255, count: height * bytesPerRow)
        for row in 0..<height {
            for col in 0..<width {
                let i = row * bytesPerRow + col * 4
                pixels[i]     = red
                pixels[i + 1] = green
                pixels[i + 2] = blue
                pixels[i + 3] = 255 // alpha
            }
        }
        let ctx = try XCTUnwrap(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        return try XCTUnwrap(ctx.makeImage())
    }

    // MARK: - fingerprint()

    func testFingerprintLengthIs256() throws {
        let image = try makeImage(red: 128, green: 128, blue: 128)
        let fp = ChangeDetector.fingerprint(of: image)
        XCTAssertEqual(fp.count, 256)
    }

    func testIdenticalImagesProduceIdenticalFingerprints() throws {
        let image = try makeImage(red: 200, green: 100, blue: 50)
        let fp1 = ChangeDetector.fingerprint(of: image)
        let fp2 = ChangeDetector.fingerprint(of: image)
        XCTAssertEqual(fp1, fp2)
    }

    func testSolidWhiteImageFingerprint() throws {
        let image = try makeImage(red: 255, green: 255, blue: 255)
        let fp = ChangeDetector.fingerprint(of: image)
        XCTAssertEqual(fp.count, 256)
        // All R-channel values should be 255 (white)
        XCTAssertTrue(fp.allSatisfy { $0 == 255 })
    }

    func testSolidBlackImageFingerprint() throws {
        let image = try makeImage(red: 0, green: 0, blue: 0)
        let fp = ChangeDetector.fingerprint(of: image)
        XCTAssertEqual(fp.count, 256)
        // All R-channel values should be 0 (black)
        XCTAssertTrue(fp.allSatisfy { $0 == 0 })
    }

    // MARK: - hasChanged()

    func testIdenticalFingerprintsNotChanged() {
        let fp: [UInt8] = Array(repeating: 100, count: 256)
        XCTAssertFalse(ChangeDetector.hasChanged(from: fp, to: fp))
    }

    func testWhiteVsBlackIsChanged() throws {
        let white = try makeImage(red: 255, green: 255, blue: 255)
        let black = try makeImage(red: 0,   green: 0,   blue: 0)
        let fpWhite = ChangeDetector.fingerprint(of: white)
        let fpBlack = ChangeDetector.fingerprint(of: black)
        XCTAssertTrue(ChangeDetector.hasChanged(from: fpWhite, to: fpBlack))
    }

    func testDifferenceAtThresholdIsNotChanged() {
        // Mean diff == threshold (4) should NOT be considered changed (uses >)
        let threshold = 4
        let previous: [UInt8] = Array(repeating: 0,   count: 256)
        let current:  [UInt8] = Array(repeating: UInt8(threshold), count: 256)
        XCTAssertFalse(ChangeDetector.hasChanged(from: previous, to: current, threshold: threshold))
    }

    func testDifferenceAboveThresholdIsChanged() {
        let threshold = 4
        let previous: [UInt8] = Array(repeating: 0,   count: 256)
        let current:  [UInt8] = Array(repeating: UInt8(threshold + 1), count: 256)
        XCTAssertTrue(ChangeDetector.hasChanged(from: previous, to: current, threshold: threshold))
    }

    func testDifferenceBelowThresholdIsNotChanged() {
        let threshold = 4
        let previous: [UInt8] = Array(repeating: 0,   count: 256)
        let current:  [UInt8] = Array(repeating: UInt8(threshold - 1), count: 256)
        XCTAssertFalse(ChangeDetector.hasChanged(from: previous, to: current, threshold: threshold))
    }

    func testEmptyArraysReturnChanged() {
        // Guard condition: mismatched or empty fingerprints are treated as changed
        // so the engine always captures when there's no prior baseline.
        XCTAssertTrue(ChangeDetector.hasChanged(from: [], to: []))
    }

    func testMismatchedLengthsReturnChanged() {
        let a: [UInt8] = Array(repeating: 0, count: 256)
        let b: [UInt8] = Array(repeating: 0, count: 128)
        XCTAssertTrue(ChangeDetector.hasChanged(from: a, to: b))
    }

    func testCustomThresholdZeroDetectsAnyDifference() {
        let previous: [UInt8] = Array(repeating: 10, count: 256)
        let current:  [UInt8] = Array(repeating: 11, count: 256)
        XCTAssertTrue(ChangeDetector.hasChanged(from: previous, to: current, threshold: 0))
    }
}
