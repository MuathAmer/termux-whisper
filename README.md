# Termux Whisper 🗣️
**Private, Offline Audio Transcription for Android**

A lightweight wrapper for [whisper.cpp](https://github.com/ggerganov/whisper.cpp) to transcribe audio files locally on Android via Termux. No internet required.

## 🚀 Quick Start

### 1. Install Termux
Download from [F-Droid](https://f-droid.org/packages/com.termux/) (Recommended) or the Google Play Store.

### 2. Setup
```bash
pkg install git -y
git clone https://github.com/MuathAmer/termux-whisper.git
cd termux-whisper
chmod +x *.sh
./setup.sh
```

### 3. Usage
**The easy way (Recommended):**
```bash
./menu.sh
```
This launches the Unified Dashboard where you can pick files, record audio, and manage models.

---

**Manual Commands:**
| Feature | Command |
| :--- | :--- |
| **Launch Dashboard** | `./menu.sh` |
| **Live Recording** | `./transcribe.sh --record` |
| **File Picker** | `./transcribe.sh --file-picker` |
| **Manage Models** | `./models.sh` |

## ✨ Features
- **One-Click Dashboard:** A professional TUI menu to access all features.
- **Live Recording:** Dictate directly into Termux and get instant transcription.
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

---
*Powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp)*
