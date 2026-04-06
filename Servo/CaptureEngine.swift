import CoreGraphics
import Network
@preconcurrency import ScreenCaptureKit
import AppKit
import Foundation

actor CaptureEngine {

    static let shared = CaptureEngine()
    private init() {}

    private var captureTask: Task<Void, Never>?
    private var lastFingerprint: [UInt8] = []
    private var lastAppName: String = ""
    private var lastWindowTitle: String? = nil

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
        // 1. Skip if screen is locked or recording permission is absent
        let locked = await MainActor.run { appState.isScreenLocked }
        guard !locked else { return }

        guard CGPreflightScreenCaptureAccess() else {
            CGRequestScreenCaptureAccess()
            return
        }

        // 2. Read current settings + active display + frontmost app on MainActor
        let (url, model, prompt, aiBackend, activeDisplayID, appName, frontmostPID, screenCount, nowPlaying) = await MainActor.run {
            let displayID = NSScreen.main
                .flatMap { $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID }
            let frontmost = NSWorkspace.shared.frontmostApplication
            let appName = frontmost?.localizedName ?? "Unknown"
            let pid = frontmost?.processIdentifier
            let screenCount = NSScreen.screens.count
            let nowPlaying = NowPlayingMonitor.shared.currentTrack
            return (appState.ollamaURL, appState.modelName, appState.systemPrompt, appState.aiBackend, displayID, appName, pid, screenCount, nowPlaying)
        }

        // Fetch window title via ScreenCaptureKit (replaces deprecated CGWindowListCopyWindowInfo)
        let windowTitle = await frontmostWindowTitle(pid: frontmostPID)

        // 3. Log observation and build context summary
        await ObservationLog.shared.append(appName: appName, windowTitle: windowTitle)
        let historicalContext = await ObservationLog.shared.contextSummary()
        let instantContext = CaptureEngine.instantContext(windowTitle: windowTitle, screenCount: screenCount, nowPlaying: nowPlaying)
        let context = instantContext + historicalContext
        let samples = PersonalityPreset.all.first { $0.prompt == prompt }?.samples ?? []

        // 4. Capture screenshot
        let cgImage: CGImage
        do {
            cgImage = try await captureDisplay(preferredDisplayID: activeDisplayID)
        } catch {
            await MainActor.run { appState.status = .error("Screen capture failed") }
            return
        }

        // 5. Change detection — skip if screen hasn't changed meaningfully
        //    Exception: always fire when the frontmost app or window title changes.
        let appOrWindowChanged = appName != lastAppName || windowTitle != lastWindowTitle
        lastAppName = appName
        lastWindowTitle = windowTitle

        let fingerprint = ChangeDetector.fingerprint(of: cgImage)
        guard appOrWindowChanged || ChangeDetector.hasChanged(from: lastFingerprint, to: fingerprint) else {
            return
        }
        lastFingerprint = fingerprint

        // 6. Call AI backend
        await MainActor.run { appState.status = .thinking }

        do {
            let utterance: String
            switch aiBackend {
            case .onDevice:
                utterance = try await OnDeviceClient().generate(
                    personality: prompt,
                    cgImage: cgImage,
                    contextItems: context,
                    samples: samples
                )
            case .ollama:
                guard let imageData = jpegData(from: cgImage, maxWidth: 1280) else { return }
                utterance = try await OllamaClient().generate(
                    baseURL: url,
                    model: model,
                    personality: prompt,
                    imageData: imageData,
                    contextItems: context,
                    samples: samples
                )
            }
            await MainActor.run {
                appState.utterance = utterance
                appState.status = .idle
                appState.speakIfEnabled(utterance)
            }
        } catch let onDeviceError as OnDeviceError {
            await MainActor.run {
                appState.utterance = "Apple Intelligence isn't available right now."
                appState.status = .error(onDeviceError.localizedDescription)
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

// MARK: - Instant context

extension CaptureEngine {
    /// Assembles all instantaneous context as a list of "Label: Value" bullet items.
    nonisolated static func instantContext(windowTitle: String?, screenCount: Int, nowPlaying: String?) -> [String] {
        var parts: [String] = []

        // User's name
        parts.append("User: \(NSFullUserName())")

        // Day + time of day + weekend flag
        let now = Date()
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayName = formatter.string(from: now)
        let hour = cal.component(.hour, from: now)
        let period: String
        switch hour {
        case 5..<12:  period = "morning"
        case 12..<17: period = "afternoon"
        case 17..<21: period = "evening"
        default:      period = "night"
        }
        let weekendSuffix = cal.isDateInWeekend(now) ? " (weekend)" : ""
        parts.append("Time: \(dayName) \(period)\(weekendSuffix)")

        // Battery + low power mode
        if let battery = BatteryInfo.current() {
            let lpm = ProcessInfo.processInfo.isLowPowerModeEnabled ? ", low power mode on" : ""
            parts.append(battery.contextString + lpm)
        } else if ProcessInfo.processInfo.isLowPowerModeEnabled {
            parts.append("Low Power Mode: On")
        }

        // Thermal state (only when notable)
        switch ProcessInfo.processInfo.thermalState {
        case .fair:     parts.append("Thermals: Running warm")
        case .serious:  parts.append("Thermals: Running hot")
        case .critical: parts.append("Thermals: Overheating")
        default:        break
        }

        // Holiday awareness
        if let holiday = HolidayInfo.current() {
            parts.append(holiday.contextString)
        }

        // Network
        if !isNetworkAvailable() {
            parts.append("Network: Offline")
        }

        // Screen count (only notable when > 1)
        if screenCount > 1 {
            parts.append("Screens: \(screenCount) connected")
        }

        // User idle time (only mention after 5 min)
        let idle = userIdleSeconds()
        if idle >= 300 {
            parts.append("User Idle: \(Int(idle / 60)) min")
        }

        // Window title
        if let title = windowTitle, !title.isEmpty {
            parts.append("Window: \(title)")
        }

        // Now playing (Spotify or Apple Music)
        if let track = nowPlaying {
            parts.append("Now playing: \(track)")
        }

        return parts
    }

    // App-lifetime monitor: started once on first access, intentionally never cancelled.
    private static let pathMonitor: NWPathMonitor = {
        let monitor = NWPathMonitor()
        monitor.start(queue: .global(qos: .background))
        return monitor
    }()

    nonisolated private static func isNetworkAvailable() -> Bool {
        pathMonitor.currentPath.status == .satisfied
    }

    /// Returns the title of the frontmost window for the given process using ScreenCaptureKit.
    /// Prefers large document-style windows over toolbars and panels.
    private func frontmostWindowTitle(pid: pid_t?) async -> String? {
        guard let pid else { return nil }
        guard let content = try? await SCShareableContent.current else { return nil }

        let owned = content.windows.filter { $0.owningApplication?.processID == pid }

        // Prefer a window large enough to be a primary document window
        let large = owned.first { $0.frame.width > 300 && $0.frame.height > 150 }
        let candidate = large ?? owned.first
        return candidate?.title.flatMap { $0.isEmpty ? nil : $0 }
    }

    nonisolated private static func userIdleSeconds() -> Double {
        let mouse = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let key   = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let click = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        return min(mouse, min(key, click))
    }
}

