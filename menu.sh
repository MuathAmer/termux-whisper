#!/bin/bash

# Termux Whisper Unified Dashboard
# Provides a TUI for easy access to all features.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANS_SCRIPT="${SCRIPT_DIR}/transcribe.sh"
MODELS_SCRIPT="${SCRIPT_DIR}/models.sh"

# Colors for non-dialog output
BLUE='\033[0;34m'
NC='\033[0m'

check_deps() {
    if ! command -v dialog &> /dev/null; then
        echo -e "${BLUE}[INFO]${NC}" "Installing 'dialog' for the menu..."
        pkg install -y dialog
    fi
}

main_menu() {
    while true; do
        exec 3>&1
        selection=$(dialog --backtitle "Termux Whisper v1.0" \
                           --title " Main Menu " \
                           --clear \
                           --cancel-label "Exit" \
                           --menu "Select an action:" 15 50 6 \
                           1 "Transcribe File (System Picker)" \
                           2 "Record & Transcribe (Live)" \
                           3 "Browse Files (TUI Picker)" \
                           4 "Manage Models" \
                           5 "Quick Settings" \
                           6 "Help / About" \
                           2>&1 1>&3)
        exit_code=$?
        exec 3>&-

        case $exit_code in
            1) exit 0 ;;
            255) exit 0 ;;
        esac

        case $selection in
            1) bash "$TRANS_SCRIPT" --file-picker ;; 
            2) bash "$TRANS_SCRIPT" --record ;; 
            3) bash "$TRANS_SCRIPT" --tui-file-picker ;; 
            4) bash "$MODELS_SCRIPT" ;; 
            5) settings_menu ;; 
            6) show_help ;; 
        esac
    done
}

settings_menu() {
    dialog --msgbox "Settings coming soon: \n- Default Model Selection\n- Subtitle Toggle\n- Thread Count" 10 40
}

show_help() {
    dialog --title "About Termux Whisper" --msgbox "Termux Whisper is a high-performance voice-to-text wrapper for whisper.cpp on Android.\n\nDeveloped for Termux.\n\nTranscripts are saved to:\n/sdcard/Download/Termux-Whisper/" 12 50
}

check_deps
main_menu
