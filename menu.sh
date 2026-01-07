#!/bin/bash

# Termux Whisper Unified Dashboard
# Text-based CLI for easy access to all features.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRANS_SCRIPT="${SCRIPT_DIR}/core/transcribe.sh"
MODELS_SCRIPT="${SCRIPT_DIR}/core/models.sh"
SHARE_SCRIPT="${SCRIPT_DIR}/core/enable_share.sh"
CONFIG_FILE="$HOME/.termux_whisper_config"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Load Config
if [ ! -f "$CONFIG_FILE" ]; then
    echo "DEFAULT_LANG=auto" > "$CONFIG_FILE"
fi
source "$CONFIG_FILE"

print_header() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}       Termux Whisper Dashboard         ${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_menu() {
    echo -e "\n${YELLOW}Choose an action:${NC}"
    echo -e "  ${GREEN}1)${NC} Transcribe File (System Picker)"
    echo -e "  ${GREEN}2)${NC} Manage Models"
    echo -e "  ${GREEN}3)${NC} Enable Share Integration"
    echo -e "  ${GREEN}4)${NC} Quick Settings"
    echo -e "  ${GREEN}5)${NC} Help / About"
    echo -e "  ${RED}q)${NC} Exit"
    echo ""
}

set_language() {
    echo -e "\n${BLUE}--- Set Default Language ---${NC}"
    echo "Current: ${DEFAULT_LANG}"
    echo "Enter language code (e.g., 'en', 'es', 'fr', 'auto'):"
    read -p "> " lang_input

    if [ -n "$lang_input" ]; then
        if grep -q "DEFAULT_LANG=" "$CONFIG_FILE"; then
            sed -i "s/DEFAULT_LANG=.*/DEFAULT_LANG=$lang_input/" "$CONFIG_FILE"
        else
            echo "DEFAULT_LANG=$lang_input" >> "$CONFIG_FILE"
        fi
        DEFAULT_LANG="$lang_input"
        echo -e "${GREEN}Language set to: $lang_input${NC}"
    else
        echo -e "${YELLOW}Cancelled.${NC}"
    fi
    read -p "Press Enter to return..." dummy
}

settings_menu() {
    while true; do
        source "$CONFIG_FILE"
        echo -e "\n${BLUE}--- Quick Settings ---${NC}"
        echo -e "  1) Set Default Language [Current: ${DEFAULT_LANG}]"
        echo -e "  2) View Config File"
        echo -e "  b) Back"
        echo ""
        read -p "Select: " opt
        case $opt in
            1) set_language ;;
            2) 
                echo -e "\n${YELLOW}--- $CONFIG_FILE ---${NC}"
                cat "$CONFIG_FILE"
                echo -e "${YELLOW}--------------------------${NC}"
                read -p "Press Enter to return..." dummy
                ;;
            b|B) return ;;
            *) echo -e "${RED}Invalid option.${NC}" ;;
        esac
    done
}

show_help() {
    echo -e "\n${BLUE}--- About Termux Whisper ---${NC}"
    echo "A high-performance wrapper for whisper.cpp."
    echo ""
    echo -e "${YELLOW}Transcripts saved to:${NC}"
    echo "/sdcard/Download/Termux-Whisper/"
    echo ""
    echo "Developed for Termux."
    read -p "Press Enter to return..." dummy
}

# Main Loop
print_header
while true; do
    print_menu
    read -p "Select option: " selection
    
    case $selection in
        1) bash "$TRANS_SCRIPT" --file-picker ;; 
        2) bash "$MODELS_SCRIPT" ;; 
        3) bash "$SHARE_SCRIPT" ;;
        4) settings_menu ;; 
        5) show_help ;;
        q|Q) 
            echo "Bye!"
            exit 0 
            ;;
        *) 
            echo -e "${RED}Invalid selection.${NC}" 
            ;;
    esac
done
