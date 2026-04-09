# Servo — Claude Code Guide

## What this is

Servo is a macOS virtual pet app that periodically captures the user's screen and uses a local Ollama vision model to generate character-driven commentary. It's a small, focused codebase (~1000 lines of Swift).

---

## Tech stack

- **Swift 6.3** — strict concurrency enforced throughout
- **SwiftUI** — all UI (`PetView`, `SettingsView`, menubar)
- **AppKit** — `NSPanel` floating window, `NSApplication` menubar integration
- **Observation framework** — `@Observable` for state (not MVVM, not TCA)
- **ScreenCaptureKit** — system screen capture
- **AVFoundation** — `AVSpeechSynthesizer` for text-to-speech
- **IOKit** — battery info
- **Network** — `NWPathMonitor` for network reachability
- **WeatherKit** — current + hourly forecast (cached; fetched at most every 6 hours)
- **CoreLocation** — one-shot location fix for WeatherKit coordinates
- **Sparkle** (SPM) — auto-update framework

---

## Build commands

```bash
# Debug
xcodebuild -scheme Servo -configuration Debug -derivedDataPath build build

# Release
xcodebuild -scheme Servo -configuration Release -derivedDataPath build build

# Open in Xcode
open Servo.xcodeproj
```

---

## Project layout

All source is in `Servo/`:

| File | Role |
|---|---|
| `ServoApp.swift` | App entry point, `@main`, menubar setup, `NSApplicationDelegate` |
| `AppState.swift` | Single `@Observable` model; all settings + runtime state; UserDefaults persistence |
| `CaptureEngine.swift` | `actor`; main capture loop — screenshot → change detect → build context → call Ollama → update state |
| `OllamaClient.swift` | HTTP client for the Ollama `/api/generate` endpoint; streams response |
| `ChangeDetector.swift` | Perceptual hash (16×16, R-channel mean) for frame diff; skips unchanged screens |
| `ObservationLog.swift` | `actor`; append-only activity log; JSON persistence; used to build app-history context |
| `BatteryInfo.swift` | IOKit wrapper returning battery percentage and charging state |
| `WeatherInfo.swift` | WeatherKit + CoreLocation helper; fetches 7 hourly slots, caches in `AppState` |
| `PetView.swift` | Character emoji + animated speech bubble; handles screen-edge repositioning |
| `FloatingPetPanel.swift` | `NSPanel` wrapper — always-on-top, non-activating, non-focus-stealing |
| `SettingsView.swift` | Settings UI; `PersonalityPreset.all` defines all built-in personalities |
| `Servo.entitlements` | Sandbox entitlements: network client, screen recording, WeatherKit, location |

---

## Architecture notes

### State management
`AppState` is the single source of truth, marked `@Observable`. Views use `@Bindable` for two-way bindings. No MVVM coordinator, no TCA store. Settings are persisted directly to UserDefaults in `didSet` observers on each property.

### Concurrency
- `CaptureEngine` and `ObservationLog` are Swift `actor`s — all shared mutable state is actor-isolated
- UI updates from background tasks go through `await MainActor.run { }`
- The capture loop runs as a long-lived `Task` started when observation begins
- Do not introduce `DispatchQueue` — use structured concurrency throughout

### Floating window
`FloatingPetPanel` wraps an `NSPanel` with `.floating` window level and `.ignoresCycle` collection behavior. It never activates (`.nonactivatingPanel` style mask). Position and size are saved to UserDefaults.

### Change detection pipeline
`ChangeDetector.isMeaningfulChange(_:from:)` computes a 16×16 perceptual hash by downsampling the frame, reading R-channel pixel values, and comparing mean absolute difference between frames. Threshold is 4. Only frames that pass this check are sent to Ollama.

### Ollama API
`OllamaClient` POSTs to `/api/generate` with `stream: false`. The request includes a system prompt (personality), a user message (context string + "What do you observe?"), and the screenshot as a base64-encoded JPEG (max width 1280px, 60% quality). Temperature is 0.9, max tokens 80.

### Context string
`CaptureEngine` builds a context string (~150 chars max) containing: time of day, battery %, thermal state, current weather, holiday awareness, network status, multi-screen detection, user idle time, frontmost app, and a summary of apps used recently (from `ObservationLog`). This string is appended to the user turn.

### Weather
`WeatherInfo.fetchSlots()` fetches 7 hourly `WeatherSlot` entries (current hour + next 6) from WeatherKit using a one-shot CoreLocation fix. Slots are cached in `AppState` (`cachedWeatherSlots`, `lastWeatherFetch`) and persisted to UserDefaults. `CaptureEngine` refreshes them at most every 6 hours via a background `weatherTask`. `AppState.currentWeatherContext` picks the slot matching the current hour, so the context updates each hour with no additional API calls.

WeatherKit requires the `com.apple.developer.weatherkit` entitlement, the WeatherKit capability enabled in Xcode Signing & Capabilities, and WeatherKit enabled on **both** the Capabilities and App Services tabs in the Apple Developer portal for the app's bundle ID.

### Holiday data
`HolidayInfo.swift` injects holiday context items (e.g., `"Today: Halloween"`, `"Upcoming: Thanksgiving (3d)"`). Fixed holidays (New Year's Day, Independence Day, etc.) repeat every year by month/day — no maintenance needed. Floating holidays (MLK Day, Thanksgiving, etc.) are hardcoded through **2030**. When approaching the end of the covered range, extend `floatingHolidays` in `HolidayInfo.swift` with dates for the next 5 years.

---

## Conventions

- **Minimal external dependencies** — Sparkle (auto-update) is the only SPM package; do not add others without discussion
- **Actors for shared state** — any new shared mutable state accessed from multiple async contexts should be actor-isolated
- **MainActor for UI** — state writes that drive UI must happen on the main actor
- **No TCA or Combine** — the codebase uses `@Observable` + async/await; don't introduce reactive or architectural frameworks
- **UserDefaults for persistence** — small settings belong in `AppState` with `didSet` UserDefaults writes; don't add a database for simple config
- **80-token response limit** — keep the pet's utterances short; prompts and context strings are deliberately constrained

---

## Testing

The `ServoTests` target is a hosted XCTest bundle (runs inside the Servo app process, required for sandboxed entitlements). Test files live in `ServoTests/`.

Current coverage:

- `ChangeDetectorTests.swift` — fingerprint length, identical-image stability, solid-color R-channel values, threshold boundary conditions, mismatched-length guard
- `OllamaClientPromptTests.swift` — `buildPrompt` section presence/absence, ordering, sample capping at 5, personality injection

Good candidates for future tests:

- `OllamaClient` network layer — testable against a mock `URLSession`
- `CaptureEngine` context string generation — pure string logic, no capture needed

When adding new test files, add them to the `ServoTests` target in Xcode (not SPM).

---

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
