# Termux Whisper Project Context

**Tech Stack:** Bash, C++ (Whisper.cpp), Termux
**Role:** Wrapper/Installer for Whisper.cpp on Android.

## 🟢 Current Status
*   **Phase:** Feature Expansion
*   **Last Update:** 2026-01-02
*   **Focus:** Unified TUI Experience & Live Recording.

## 📚 Documentation Architecture
1.  **`README.md`:** User-facing guide. Public.
2.  **`menu.sh`:** The main entry point (Dashboard).
3.  **`setup.sh`:** The installer. Handles dependencies and compilation.
4.  **`models.sh`:** Model management menu.
5.  **`transcribe.sh`:** The main execution wrapper. Supports --record.

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
    4.  **Interface Consistency:** Every new feature must be reflected in the internal `--help`/usage output, the main menu, and external documentation before completion.
</PROTOCOL:ACT>

<PROTOCOL:VERIFY>
*   **Objective:** Prevent Documentation Rot and Discovery Issues.
*   **Action:**
    1.  Always test the 'Discovery Path': Run the script without arguments to ensure new features are visible in the help menu.
    2.  Verify the "Definition of Done": Logic + Internal Help + External Docs + UI Menu.
</PROTOCOL:VERIFY>

<PROTOCOL:WORKFLOW>
*   **Objective:** Git & Documentation Best Practices.
*   **Action:**
    1.  Automatically create a commit (following conventional commits) as soon as a complete change is made.
    2.  Automatically push changes to the remote repository immediately after committing.
    3.  Always maintain synchronized updates across all sources (code, README.md, and GEMINI.md) for every new feature or change.
</PROTOCOL:WORKFLOW>
