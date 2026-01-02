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
                           --menu "Select an action:" 16 50 7 \
                           1 "Transcribe File (System Picker)" \
                           2 "Record & Transcribe (Live)" \
                           3 "Browse Files (TUI Picker)" \
                           4 "Manage Models" \
                           5 "Enable Share Integration" \
                           6 "Quick Settings" \
                           7 "Help / About" \
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
            5) bash "${SCRIPT_DIR}/enable_share.sh" ;;
            6) settings_menu ;; 
            7) show_help ;; 
        esac
    done
}

CONFIG_FILE="$HOME/.termux_whisper_config"

# Load Config (create if missing)
if [ ! -f "$CONFIG_FILE" ]; then
    echo "DEFAULT_LANG=auto" > "$CONFIG_FILE"
fi
source "$CONFIG_FILE"

settings_menu() {
    while true; do
        # Reload config to reflect changes
        source "$CONFIG_FILE"
        
        exec 3>&1
        selection=$(dialog --title " Quick Settings " \
                           --clear \
                           --cancel-label "Back" \
                           --menu "Current Language: [${DEFAULT_LANG}]" 12 50 2 \
                           1 "Set Default Language" \
                           2 "View Config File" \
                           2>&1 1>&3)
        exit_code=$?
        exec 3>&-

        if [ $exit_code -ne 0 ]; then return; fi

        case $selection in
            1) set_language ;;
            2) dialog --title "Configuration" --textbox "$CONFIG_FILE" 10 50 ;;
        esac
    done
}

set_language() {
    exec 3>&1
    lang=$(dialog --title "Select Language" \
                  --menu "Choose default language:" 20 50 15 \
                  "auto" "Auto-Detect (Default)" \
                  "en" "English" \
                  "es" "Spanish" \
                  "fr" "French" \
                  "de" "German" \
                  "it" "Italian" \
                  "pt" "Portuguese" \
                  "ru" "Russian" \
                  "zh" "Chinese" \
                  "ar" "Arabic" \
                  "ja" "Japanese" \
                  "ko" "Korean" \
                  "hi" "Hindi" \
                  2>&1 1>&3)
    exec 3>&-
    
    if [ -n "$lang" ]; then
        # Update Config using sed to preserve other potential future settings
        if grep -q "DEFAULT_LANG=" "$CONFIG_FILE"; then
            sed -i "s/DEFAULT_LANG=.*/DEFAULT_LANG=$lang/" "$CONFIG_FILE"
        else
            echo "DEFAULT_LANG=$lang" >> "$CONFIG_FILE"
        fi
        dialog --msgbox "Language set to: $lang" 6 30
    fi
}

show_help() {
    dialog --title "About Termux Whisper" --msgbox "Termux Whisper is a high-performance voice-to-text wrapper for whisper.cpp on Android.\n\nDeveloped for Termux.\n\nTranscripts are saved to:\n/sdcard/Download/Termux-Whisper/" 12 50
}

check_deps
main_menu
