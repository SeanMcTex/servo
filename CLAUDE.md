# Servo — Claude Code Guide

## What this is

Servo is a macOS virtual pet app that periodically captures the user's screen and uses a local Ollama vision model to generate character-driven commentary. It's a small, focused codebase (~800 lines of Swift) with no external dependencies.

---

## Tech stack

- **Swift 6.3** — strict concurrency enforced throughout
- **SwiftUI** — all UI (`PetView`, `SettingsView`, menubar)
- **AppKit** — `NSPanel` floating window, `NSApplication` menubar integration
- **Observation framework** — `@Observable` for state (not MVVM, not TCA)
- **ScreenCaptureKit** — system screen capture
- **AVFoundation** — `AVSpeechSynthesizer` for text-to-speech
- **IOKit** — battery info
- **SystemConfiguration** — network reachability
- **No Swift Package Manager dependencies** — pure Xcode project (`Servo.xcodeproj`)

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
| `PetView.swift` | Character emoji + animated speech bubble; handles screen-edge repositioning |
| `FloatingPetPanel.swift` | `NSPanel` wrapper — always-on-top, non-activating, non-focus-stealing |
| `SettingsView.swift` | Settings UI; `PersonalityPreset.all` defines all built-in personalities |
| `Servo.entitlements` | Sandbox entitlements: network client, screen recording |

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
`CaptureEngine` builds a context string (~150 chars max) containing: time of day, battery %, thermal state, network status, multi-screen detection, user idle time, frontmost app, and a summary of apps used recently (from `ObservationLog`). This string is appended to the user turn.

---

## Conventions

- **No external dependencies** — do not add SPM packages without discussion; the zero-dependency property is intentional
- **Actors for shared state** — any new shared mutable state accessed from multiple async contexts should be actor-isolated
- **MainActor for UI** — state writes that drive UI must happen on the main actor
- **No TCA or Combine** — the codebase uses `@Observable` + async/await; don't introduce reactive or architectural frameworks
- **UserDefaults for persistence** — small settings belong in `AppState` with `didSet` UserDefaults writes; don't add a database for simple config
- **80-token response limit** — keep the pet's utterances short; prompts and context strings are deliberately constrained

---

## Testing

No test target exists yet. Good candidates for unit tests:

- `ChangeDetector` — pure function, easy to test with synthetic CGImages
- `OllamaClient` — can be tested against a mock URLSession
- `CaptureEngine` context string generation — pure string logic, no capture needed

If adding tests, create a new `ServoTests` target in Xcode (not SPM).

---

## Issue tracking

The project uses [Beads](https://beads.dev), a local issue tracker. Issues live in `.beads/`. Use the `br` CLI to interact with them:

```bash
br --help
br update:bd-2po   # update an issue
br comments:bd-2po # view comments on an issue
```

The `issues.jsonl` file is the exported issue list and is committed to the repo.
