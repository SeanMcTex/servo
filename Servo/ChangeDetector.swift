import CoreGraphics
import Foundation

struct ChangeDetector {

    // MARK: - Fingerprint

    /// Downsamples `image` to 16×16 and returns the 256 R-channel byte values.
    nonisolated static func fingerprint(of image: CGImage) -> [UInt8] {
        let side = 16
        let bytesPerRow = side * 4
        var pixels = [UInt8](repeating: 0, count: side * bytesPerRow)

        guard let ctx = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Return R channel only (every 4th byte starting at index 0)
        return stride(from: 0, to: pixels.count, by: 4).map { pixels[$0] }
    }

    // MARK: - Comparison

    /// Returns true if the mean absolute difference between fingerprints exceeds `threshold`.
    nonisolated static func hasChanged(from previous: [UInt8], to current: [UInt8], threshold: Int = 4) -> Bool {
        guard previous.count == current.count, !previous.isEmpty else { return true }
        let sum = zip(previous, current).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
        return (sum / previous.count) > threshold
    }
}
