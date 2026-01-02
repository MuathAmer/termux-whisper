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
**Download a model:**
```bash
./models.sh  # Choose 'Small' for best results
```

**Transcribe:**
```bash
./transcribe.sh [file_or_folder] [--model model_name] [--subs] [--native]
```

**Examples:**
```bash
# Interactive Mode (Uses 'small' model by default)
./transcribe.sh

# Use 'base' model with Interactive Picker
./transcribe.sh --model base

# Use Android System Picker
./transcribe.sh --native --model small

# Manual Mode
./transcribe.sh /sdcard/Download/note.m4a --model base
```

## ✨ Features
- **Privacy:** 100% offline; data stays on your device.
- **Interactive:** Visual file picker (Dialog or Native Android).
- **Batch:** Transcribe single files or entire directories.
- **Subtitles:** Optionally generate `.srt` and `.vtt` files.
- **Formats:** Supports MP3, WAV, M4A, OPUS, OGG, FLAC, MP4, MKV.
- **Optimized:** Works best on modern Pixel and Snapdragon devices.

## ⚠️ Notes on Pickers
*   **Dialog (Default):** Browses files inside Termux. Saves transcripts **next to the original file**.
*   **Native (`--native`):** Opens Android's system picker. Saves transcripts to `/sdcard/Download/Termux-Whisper/` because the original path is hidden from Termux. **Requires `Termux:API` app.**

---
*Powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp)*
