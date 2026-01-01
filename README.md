# Termux Whisper 🗣️
**Private, Offline Audio Transcription for Android**

A lightweight wrapper for [whisper.cpp](https://github.com/ggerganov/whisper.cpp) to transcribe audio files locally on Android via Termux. No internet required.

## 🚀 Quick Start

### 1. Install Termux
Download from [F-Droid](https://f-droid.org/packages/com.termux/) (Recommended) or the Google Play Store.

### 2. Setup
```bash
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
./transcribe.sh <file_or_folder> [model_name]

# Example
./transcribe.sh /sdcard/Download/note.m4a
```

## ✨ Features
- **Privacy:** 100% offline; data stays on your device.
- **Batch:** Transcribe single files or entire directories.
- **Formats:** Supports MP3, WAV, M4A, OPUS, OGG, FLAC.
- **Optimized:** Works best on modern Pixel and Snapdragon devices.

---
*Powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp)*