import CoreGraphics
import ScreenCaptureKit
import AppKit
import Foundation

actor CaptureEngine {

    static let shared = CaptureEngine()
    private init() {}

    private var captureTask: Task<Void, Never>?
    private var lastFingerprint: [UInt8] = []

    // MARK: - Start / Stop

    func start(appState: AppState) {
        captureTask?.cancel()
        captureTask = Task {
            while !Task.isCancelled {
                await runCycle(appState: appState)
                let interval = await MainActor.run { appState.captureInterval }
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stop() {
        captureTask?.cancel()
        captureTask = nil
    }

    // MARK: - Single capture cycle

    private func runCycle(appState: AppState) async {
        // 1. Check/request screen recording permission
        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            return
        }

        // 2. Read current settings + active display ID on MainActor
        let (url, model, prompt, activeDisplayID) = await MainActor.run {
            let displayID = NSScreen.main
                .flatMap { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID }
            return (appState.ollamaURL, appState.modelName, appState.systemPrompt, displayID)
        }

        // 3. Capture screenshot
        let cgImage: CGImage
        do {
            cgImage = try await captureDisplay(preferredDisplayID: activeDisplayID)
        } catch {
            await MainActor.run { appState.status = .error("Screen capture failed") }
            return
        }

        // 4. Change detection — skip if screen hasn't changed meaningfully
        let fingerprint = ChangeDetector.fingerprint(of: cgImage)
        guard ChangeDetector.hasChanged(from: lastFingerprint, to: fingerprint) else {
            return
        }
        lastFingerprint = fingerprint

        // 5. Resize and JPEG-encode
        guard let imageData = jpegData(from: cgImage, maxWidth: 1280) else {
            return
        }

        // 6. Call Ollama
        await MainActor.run { appState.status = .thinking }

        do {
            let utterance = try await OllamaClient().generate(
                baseURL: url,
                model: model,
                systemPrompt: prompt,
                imageData: imageData
            )
            await MainActor.run {
                appState.utterance = utterance
                appState.status = .idle
                appState.speakIfEnabled(utterance)
            }
        } catch let urlError as URLError where urlError.isConnectionRefused {
            await MainActor.run {
                appState.utterance = "I seem to have lost my brain… Is Ollama running?"
                appState.status = .error("Ollama not running")
            }
        } catch {
            await MainActor.run {
                appState.utterance = "Hmm, something went wrong."
                appState.status = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - ScreenCaptureKit

    private func captureDisplay(preferredDisplayID: CGDirectDisplayID?) async throws -> CGImage {
        let content = try await SCShareableContent.current

        // Prefer the display containing the active window; fall back to first available
        let display: SCDisplay
        if let id = preferredDisplayID,
           let match = content.displays.first(where: { $0.displayID == id }) {
            display = match
        } else if let first = content.displays.first {
            display = first
        } else {
            throw CaptureError.noDisplay
        }

        let servoApp = content.applications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let excludedApps = servoApp.map { [$0] } ?? []
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])

        let config = SCStreamConfiguration()
        let targetWidth = min(display.width, 1280)
        let scale = Double(targetWidth) / Double(display.width)
        config.width = targetWidth
        config.height = Int(Double(display.height) * scale)

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    // MARK: - Image encoding

    private func jpegData(from image: CGImage, maxWidth: Int) -> Data? {
        // Resize if needed — SCStreamConfiguration already limits size,
        // but apply a safety downscale just in case
        let targetImage: CGImage
        if image.width > maxWidth {
            let scale = Double(maxWidth) / Double(image.width)
            let targetHeight = Int(Double(image.height) * scale)
            guard let ctx = CGContext(
                data: nil,
                width: maxWidth,
                height: targetHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return nil }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: maxWidth, height: targetHeight))
            targetImage = ctx.makeImage() ?? image
        } else {
            targetImage = image
        }

        let rep = NSBitmapImageRep(cgImage: targetImage)
        return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.6])
    }
}

// MARK: - Errors

private enum CaptureError: Error {
    case noDisplay
}
