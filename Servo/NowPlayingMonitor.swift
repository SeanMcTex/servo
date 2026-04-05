import Foundation
import AppKit

@MainActor
final class NowPlayingMonitor {
    static let shared = NowPlayingMonitor()

    private(set) var currentTrack: String?

    private var spotifyTrack: String?
    private var musicTrack: String?
    private var pollTask: Task<Void, Never>?

    private init() {
        startSpotifyObserver()
        startMusicPoller()
    }

    // MARK: - Spotify (DistributedNotifications)

    private func startSpotifyObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(spotifyStateChanged(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        print("[NowPlaying] Registered Spotify distributed notification observer")
    }

    @objc private func spotifyStateChanged(_ notification: Notification) {
        let state = notification.userInfo?["Player State"] as? String ?? "nil"
        let artist = notification.userInfo?["Artist"] as? String ?? ""
        let name   = notification.userInfo?["Name"]   as? String ?? ""
        print("[NowPlaying] Spotify: state=\(state) artist=\(artist.isEmpty ? "(none)" : artist) track=\(name.isEmpty ? "(none)" : name)")

        guard let info = notification.userInfo,
              (info["Player State"] as? String) == "Playing" else {
            spotifyTrack = nil
            updateCurrentTrack()
            return
        }

        let parts = [artist, name].filter { !$0.isEmpty }
        spotifyTrack = parts.isEmpty ? nil : parts.joined(separator: " — ")
        updateCurrentTrack()
    }

    // MARK: - Apple Music (AppleScript polling)

    private func startMusicPoller() {
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.pollAppleMusic()
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    private func pollAppleMusic() async {
        let musicRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.Music"
        }
        guard musicRunning else {
            if musicTrack != nil {
                print("[NowPlaying] Music: app not running, clearing track")
                musicTrack = nil
                updateCurrentTrack()
            }
            return
        }

        let result = await Task.detached(priority: .background) {
            let source = """
            tell application "Music"
                if player state is playing then
                    set t to name of current track
                    set a to artist of current track
                    if a is "" then return t
                    return a & " \u{2014} " & t
                else
                    return ""
                end if
            end tell
            """
            guard let script = NSAppleScript(source: source) else { return ("", "NSAppleScript init failed") }
            var errorDict: NSDictionary?
            let descriptor = script.executeAndReturnError(&errorDict)
            if let err = errorDict {
                return ("", "AppleScript error: \(err)")
            }
            return (descriptor.stringValue ?? "", "")
        }.value

        let (trackResult, errorMsg) = result
        if !errorMsg.isEmpty {
            print("[NowPlaying] Music: \(errorMsg)")
        } else {
            print("[NowPlaying] Music: \(trackResult.isEmpty ? "(not playing)" : trackResult)")
        }

        let newTrack: String? = trackResult.isEmpty ? nil : trackResult
        if newTrack != musicTrack {
            musicTrack = newTrack
            updateCurrentTrack()
        }
    }

    // MARK: - Resolution

    private func updateCurrentTrack() {
        currentTrack = musicTrack ?? spotifyTrack
    }
}
