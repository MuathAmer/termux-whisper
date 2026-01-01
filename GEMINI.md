# Termux Whisper Project Context

**Tech Stack:** Bash, C++ (Whisper.cpp), Termux
**Role:** Wrapper/Installer for Whisper.cpp on Android.

## 🟢 Current Status
*   **Phase:** Initial Release
*   **Last Update:** 2026-01-01
*   **Focus:** providing a "One-Click" experience for Android users.

## 📚 Documentation Architecture
1.  **`README.md`:** User-facing guide. Public.
2.  **`setup.sh`:** The installer. Handles dependencies and compilation.
3.  **`models.sh`:** Model management menu.
4.  **`transcribe.sh`:** The main execution wrapper.

## 🛡️ Gated Protocols

<PROTOCOL:PERCEIVE>
*   **Objective:** Maintain Wrapper Integrity.
*   **Action:**
    1.  Ensure we don't break compatibility with upstream `whisper.cpp`.
    2.  Keep paths relative (`./whisper.cpp/...`).
*   **Constraint:** Do not modify the `whisper.cpp` submodule code directly if possible.
</PROTOCOL:PERCEIVE>

<PROTOCOL:ACT>
*   **Objective:** Improve UX.
*   **Action:**
    1.  Keep scripts executable.
    2.  Use colors for CLI output.
    3.  Automate "boring" stuff (ffmpeg conversion).
</PROTOCOL:ACT>
