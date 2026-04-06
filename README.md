# Servo

A macOS virtual pet that watches your screen and has opinions about it.

Servo lives in a floating window on your desktop, peeks at your screen every 30 seconds, and reacts to what it sees. No cloud, no subscriptions, no data leaving your machine.

---

## Features

- **Screen-aware commentary** — uses ScreenCaptureKit to capture your display and a vision model to understand what's on it
- **Two AI backends** — Apple Intelligence (on-device, default) or a local Ollama vision model
- **14 built-in personalities** — from HAL 9000 to a Barfly Know-It-All; each reacts to the same activity in a completely different voice
- **Custom personalities** — write your own system prompt to create any character you want
- **Rich context** — incorporates time of day, battery state, thermal state, network status, user idle time, now-playing media, and recent app history into each prompt
- **Smart change detection** — only sends a new frame to the model when something meaningful has changed on screen (perceptual hash comparison)
- **Text-to-speech** — optionally speaks its observations aloud using the system voice
- **Always-on-top floating window** — stays visible but never steals focus
- **Fully local** — all processing happens on your machine; no data is sent to any external service

---

## Requirements

- macOS 26.2 or later
- Xcode 26.3 or later (for building from source)
- **Apple Intelligence backend**: Apple Intelligence must be enabled in System Settings
- **Ollama backend**: [Ollama](https://ollama.com) running locally with a vision-capable model installed

---

## Getting Started

### 1. Clone and build

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

### 2. Grant permissions

On first launch, macOS will prompt for **Screen Recording** permission. Servo requires this to capture your display. Grant it in **System Settings > Privacy & Security > Screen Recording**.

### 3. Choose a backend

Open **Settings** from the Servo menubar icon and pick a backend:

**Apple Intelligence** (default) — uses the on-device model via Apple's Foundation Models framework. Works out of the box if Apple Intelligence is enabled. Requires no additional setup, but only sees a region of the screen rather than the full display.

**Ollama** — uses a local vision model running in Ollama, with access to the full screen capture. Better at reading text-heavy interfaces and produces richer observations. Requires a bit of setup (see below), but the results are worth it.

### 4. (Optional) Set up Ollama

```bash
# Install via Homebrew
brew install ollama

# Pull a vision model — pick one:
ollama pull gemma4:26b       # fast, high quality
ollama pull llama3.2-vision  # slower, more varied responses

# Start the server (if not already running)
ollama serve
```

In Settings, set the backend to **Ollama**, confirm the URL (`http://localhost:11434` by default), enter your model name, and click **Test Connection**.

#### Recommended models

| Model | Notes |
|---|---|
| `gemma4:26b` | Fast, high-quality responses; good default choice |
| `llama3.2-vision` | Slower, but produces more varied and sometimes surprising results |

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
| **Hyperkinetic Leprechaun** | Exuberant, barely-contained energy. Everything is treasure, adventure, or outrage. |
| **Conspiracy Theorist** | Everything on screen is fresh evidence. Sees the threads others miss. |
| **Trivia Master** | Shares a genuine, surprising fact related to whatever is on screen |
| **Barfly Know-It-All** | Dispenses made-up trivia with supreme confidence and zero self-awareness |

You can also write a fully custom system prompt in Settings.

---

## Architecture

Servo is a small, focused macOS app with no external Swift dependencies — just native frameworks:

- **ScreenCaptureKit** captures your display at configurable intervals, excluding the Servo window itself
- **ChangeDetector** computes a 16×16 perceptual hash of each frame and skips frames that haven't changed meaningfully (threshold: mean absolute difference > 4), avoiding redundant model calls
- **CaptureEngine** (a Swift `actor`) runs the capture loop, builds a context string from system state and recent activity history, encodes the frame as JPEG, and calls the active backend
- **OnDeviceClient** uses Apple's Foundation Models framework for on-device inference
- **OllamaClient** sends requests to the Ollama `/api/chat` endpoint with `think: false` to disable extended reasoning
- **AppState** (`@Observable`) holds all settings and runtime state; settings are persisted to UserDefaults
- **PetView** renders the character emoji and animated speech bubble in a floating `NSPanel`

Everything runs locally. Screenshots are only sent to your local Ollama server (if using the Ollama backend) or processed entirely on-device (if using Apple Intelligence).

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
- `emoji` — the character's avatar
- `greeting` — shown when the personality is first selected

The prompt receives no special context injection beyond what the user configures; the capture engine always appends current system context and recent activity history to the user turn.

### Reporting issues

Please file issues on GitHub with:
- macOS version
- Backend (Apple Intelligence or Ollama) and model name if applicable
- A description of the unexpected behavior

---

## License

MIT — see [LICENSE](LICENSE).
