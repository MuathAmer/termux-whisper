# Termux Whisper 🗣️
**Private, Offline Audio Transcription for Android**

A lightweight wrapper for [whisper.cpp](https://github.com/ggerganov/whisper.cpp) to transcribe audio files locally on Android via Termux. No internet required.

## 🚀 Quick Start

### 1. Install & Setup (One-Liner)
Open Termux and paste this command:
```bash
curl -sL https://raw.githubusercontent.com/itsmuaaz/termux-whisper/main/install.sh | bash
```
This will install all dependencies, fetch the engine, and compile it automatically.

---

### 2. Manual Installation (Alternative)
If you prefer to do it step-by-step:
```bash
pkg install git -y
git clone https://github.com/itsmuaaz/termux-whisper.git
cd termux-whisper
chmod +x core/*.sh menu.sh
./core/setup.sh
```

### 3. Usage
**The easy way (Recommended):**
Restart Termux, then type:
```bash
whisper
```
This launches the Unified Dashboard where you can pick files, record audio, and manage models.

---

**Manual Commands:**
| Feature | Command |
| :--- | :--- |
| **Launch Dashboard** | `./menu.sh` |
| **Dictation Mode** | `./core/transcribe.sh --record` |
| **File Picker** | `./core/transcribe.sh --file-picker` |
| **Manage Models** | `./core/models.sh` |

## ✨ Features
- **One-Click Dashboard:** A professional TUI menu to access all features.
- **Dictation Mode:** Record voice notes directly in Termux and transcribe them automatically.
- **Share to Transcribe:** Share audio files from WhatsApp or File Manager directly to Termux.
- **Privacy:** 100% offline; data stays on your device.
- **Smart:** Auto-detects audio formats (including OPUS/OGG) and checks for audio streams.
- **Interactive:** Visual file picker via Android System (`--file-picker`) or Terminal (`--tui-file-picker`).
- **Live Progress:** Real-time feedback showing transcription segments and timestamps.
- **Convenient:** Prompts to open the transcript immediately after processing.
- **Batch:** Transcribe single files or entire directories.
- **Subtitles:** Optionally generate `.srt` and `.vtt` files.
- **Formats:** Supports MP3, WAV, M4A, OPUS, OGG, FLAC, MP4, MKV, AVI, MOV.

## ⚠️ Notes on Pickers
*   **Native (`--file-picker`):** Opens Android's system file picker. Automatically handles file importing and format detection. Saves transcripts to `/sdcard/Download/Termux-Whisper/`. **Requires `Termux:API` app.**
*   **Dialog (`--tui-file-picker`):** Browses files inside Termux using a text-based UI. Saves transcripts **next to the original file**. Requires `pkg install dialog`.

## 🌟 See Also
Check out [**Termux Bootstrap**](https://github.com/itsmuaaz/termux-bootstrap) – A modular, safe, and mobile-optimized script to transform Termux into a powerful development environment. It includes this project as a community extra!

---
*Powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp)*
