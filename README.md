# Servo

A macOS virtual pet that watches your screen and has opinions about it.

Servo lives in a floating window on your desktop, peeks at your screen every 30 seconds, and reacts to what it sees — powered entirely by a local Ollama vision model. No cloud, no subscriptions, no data leaving your machine.

---

## Features

- **Screen-aware commentary** — uses ScreenCaptureKit to capture your display and a local vision model (LLaVA or similar) to understand what's on it
- **10 built-in personalities** — from HAL 9000 to a Disappointed Parent; each reacts to the same activity in a completely different voice
- **Custom personalities** — write your own system prompt to create any character you want
- **Rich context** — incorporates time of day, battery state, thermal state, network status, user idle time, and recent app history into each prompt
- **Smart change detection** — only sends a new frame to the model when something meaningful has changed on screen (perceptual hash comparison)
- **Text-to-speech** — optionally speaks its observations aloud using the system voice
- **Always-on-top floating window** — stays visible but never steals focus
- **Fully local** — all processing happens on your machine via Ollama; no data is sent to any external service

---

## Requirements

- macOS 26.2 or later
- Xcode 26.3 or later (for building from source)
- [Ollama](https://ollama.com) running locally
- A vision-capable model installed in Ollama (e.g. `llava`, `llava-llama3`, `moondream`)

---

## Getting Started

### 1. Install and start Ollama

```bash
# Install via Homebrew
brew install ollama

# Pull a vision model
ollama pull llava

# Start the server (if not already running)
ollama serve
```

### 2. Clone and build

```bash
git clone https://github.com/your-username/Servo.git
cd Servo
open Servo.xcodeproj
```

Press **Cmd+R** in Xcode to build and run, or build from the command line:

```bash
xcodebuild -scheme Servo -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Servo.app
```

### 3. Grant permissions

On first launch, macOS will prompt for **Screen Recording** permission. Servo requires this to capture your display. Grant it in **System Settings > Privacy & Security > Screen Recording**.

### 4. Configure

Click the Servo menubar icon and open **Settings** to:

- Set the **Ollama URL** (default: `http://localhost:11434`)
- Choose a **model** (default: `llava`)
- Select a **personality**
- Adjust the **capture interval** (how often Servo looks at your screen)
- Enable or disable **speech**

---

## Personalities

| Name | Description |
|---|---|
| **Curious Naturalist** | Observes your activity like a nature documentary narrator describing an unusual specimen |
| **HAL 9000** | Unfailingly courteous, precise, and slightly unsettling. Calls you Dave. |
| **Marvin the Paranoid Android** | Cosmically depressed, profoundly intelligent, profoundly unimpressed |
| **Enthusiastic Companion** | Boundlessly thrilled by everything you're doing, as if doing it together |
| **Grid Observer** | A Program on The Grid observing the User's cycles with reverence and bewilderment |
| **Sports Commentator** | Live play-by-play of your screen activity as a major sporting event |
| **Ancient Curse** | A malevolent presence. Patient. Watching. Waiting. |
| **Disappointed Parent** | Loving but wistful. Had higher hopes. Still proud of you, mostly. |
| **Ship's Computer** | Neutral, precise, faintly omniscient sensor readings of crew behaviour |
| **Anxious Weather Forecaster** | Treats your screen activity as meteorological conditions requiring a forecast |

You can also write a fully custom system prompt in Settings.

---

## Architecture

Servo is a small, focused macOS app with no external Swift dependencies — just native frameworks:

- **ScreenCaptureKit** captures your display at configurable intervals, excluding the Servo window itself
- **ChangeDetector** computes a 16×16 perceptual hash of each frame and skips frames that haven't changed meaningfully (threshold: mean absolute difference > 4), avoiding redundant API calls
- **CaptureEngine** (a Swift `actor`) runs the capture loop, builds a context string from system state and recent activity history, encodes the frame as JPEG, and calls the Ollama API
- **OllamaClient** sends the request and streams back the response
- **AppState** (`@Observable`) holds all settings and runtime state; settings are persisted to UserDefaults
- **PetView** renders the character emoji and animated speech bubble in a floating `NSPanel`

Everything runs locally. Screenshots are only sent to your local Ollama server.

---

## Contributing

Contributions are welcome — bug fixes, new personalities, new features, or documentation improvements.

### Setup

The project has no Swift Package Manager dependencies, so just clone and open in Xcode.

### Pull requests

- Keep PRs focused; one change per PR
- Match the existing code style (Swift 6.3, `@Observable`, async/await, actors)
- If adding a personality, add it to `PersonalityPreset.all` in `SettingsView.swift`

### Adding a personality

Personalities are defined in `Servo/SettingsView.swift` in the `PersonalityPreset.all` array. Each preset has:

- `id` — a short unique string (used for identity comparison, not displayed)
- `name` — displayed in the Settings picker
- `prompt` — the system prompt that defines the character's voice

The prompt receives no special context injection beyond what the user configures; the capture engine always appends current system context and recent activity history to the user turn.

### Reporting issues

Please file issues on GitHub with:
- macOS version
- Ollama version and model name
- A description of the unexpected behavior

---

## License

MIT — see [LICENSE](LICENSE).
