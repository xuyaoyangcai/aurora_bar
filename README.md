# Aurora Bar

A minimalist, frameless desktop task manager for Windows. Sits at the edge of your screen as a subtle bar, expands into a full panel when clicked.

## Features

- **Semantic Task Input** — Type naturally in Chinese (e.g. "明天下午3点交数学作业"), auto-parses due date and tags
- **AI-Powered NLP** — Local Ollama model (qwen2.5:1.5b) for smarter parsing, falls back to regex
- **Dynamic Background** — Time-of-day gradient + weather-driven aurora shader + particle effects (rain/snow/clouds/fog)
- **Mood Tracking** — 5 moods (calm/focused/energetic/tired/creative) influence the color palette
- **Weather** — Auto-fetched from wttr.in, drives particles and theme overlay
- **Three Window States** — Collapsed bar (360x60) → Expanded panel (360x420) → Peek strip (28x60)
- **Swipe Gestures** — Swipe right to complete, left to delete
- **Tap to Edit** — Tap any task to edit title, category, or due date

## Tech Stack

- **Flutter** (Dart) — cross-platform desktop framework
- **window_manager** — frameless, always-on-top, transparent window
- **FragmentShader** (GLSL) — GPU aurora effect
- **Ollama** — local LLM for NLP (qwen2.5:1.5b)
- **wttr.in** — free weather API

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run -d windows

# Build release exe
flutter build windows
```

### Ollama (optional, for smart NLP)

1. Install [Ollama](https://ollama.com)
2. (Optional) Set model storage path if you want models on a different drive:
   ```bash
   setx OLLAMA_MODELS "D:\ollama\models"
   ```
3. Pull the model (~986 MB):
   ```bash
   ollama pull qwen2.5:1.5b
   ```
4. Make sure Ollama is running (tray icon or `ollama serve`)
5. Verify:
   ```bash
   ollama list
   # Should show: qwen2.5:1.5b  |  986 MB
   ```

The app calls Ollama at `http://localhost:11434` with a 4-second timeout. On failure or timeout, it falls back to regex-based Chinese NLP — still functional for common patterns like "明天下午3点交作业".

## Project Structure

```
lib/
├── main.dart                  — Window setup & app entry
├── models/todo.dart           — Todo data model
├── state/app_state.dart       — Central state (ChangeNotifier)
├── services/
│   ├── storage_service.dart   — JSON persistence
│   ├── weather_service.dart   — wttr.in weather
│   ├── nlp_parser.dart        — Regex NLP parser
│   ├── ollama_nlp_service.dart— Ollama NLP service
│   ├── note_linker.dart       — Notes directory linking
│   └── theme_engine.dart      — Dynamic color palette
├── widgets/                   — UI components
└── shaders/aurora.frag        — GPU aurora shader
```
