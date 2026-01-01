# Termux Whisper 🗣️
**Offline, Private Audio Transcription for Android**

This project provides a simple, automated wrapper around [whisper.cpp](https://github.com/ggerganov/whisper.cpp) specifically designed for Android users via Termux. It allows you to transcribe meetings, voice notes, and interviews locally on your device—no internet required, no data uploaded to the cloud.

> **🚀 Optimized for:** Pixel 6/7/8/9 (Tensor Chips) and modern Snapdragon flagships.

## ✨ Features
*   **100% Offline:** Data never leaves your phone.
*   **Simple Setup:** One command to install everything.
*   **Batch Processing:** Transcribe single files or entire folders.
*   **Format Support:** MP3, WAV, M4A, OPUS, OGG, FLAC.

---

## 🛠️ Installation

### 1. Install Termux
Download **Termux** from [F-Droid](https://f-droid.org/packages/com.termux/).
*(⚠️ Do not use the Play Store version; it is outdated and will not work.)*

### 2. Clone & Setup
Open Termux and run these commands:

```bash
# 1. Clone this repository
git clone https://github.com/your-username/termux-whisper.git

# 2. Enter the folder
cd termux-whisper

# 3. Run the installer
chmod +x setup.sh
./setup.sh
```
*The setup script will install necessary tools (ffmpeg, cmake, etc.), clone the Whisper engine, and compile it for your device.*

---

## 🚀 Usage

### Step 1: Download a Model
Before transcribing, you need an AI model. Run:
```bash
chmod +x models.sh
./models.sh
```
*   **Recommended:** Choose `Small` (Option 3) for the best balance of speed and accuracy on mobile.
*   **Fastest:** Choose `Tiny`.
*   **Most Accurate:** Choose `Medium` (requires ~4GB RAM).

### Step 2: Transcribe Audio
You can transcribe a single file or a whole folder. The output text file is saved in the same location as the audio.

**Command Syntax:**
```bash
chmod +x transcribe.sh
./transcribe.sh <path_to_audio> [model_name]
```

**Examples:**
```bash
# Transcribe a single file (uses 'small' model by default)
./transcribe.sh /sdcard/Download/interview.m4a

# Transcribe an entire folder
./transcribe.sh /sdcard/VoiceRecorder/

# Use a specific model (e.g., tiny)
./transcribe.sh /sdcard/Download/meeting.mp3 tiny
```

---

## 📱 Performance Tips (Pixel / Tensor)
*   **Threads:** The script defaults to 4 threads, which is optimal for Pixel Tensor chips.
*   **Battery:** Heavy transcription drains battery. Plug in for long batches.
*   **Storage:** Run `termux-setup-storage` if you can't access your files.

## 🤝 Credits
*   **Engine:** [whisper.cpp](https://github.com/ggerganov/whisper.cpp) by Georgi Gerganov.
*   **Model:** [OpenAI Whisper](https://openai.com/research/whisper).
