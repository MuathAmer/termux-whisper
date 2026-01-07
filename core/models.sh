#!/bin/bash

# Configuration
# Resolve Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="${PROJECT_ROOT}/whisper.cpp/models"

# Points to the official downloader inside the submodule
DOWNLOADER="${PROJECT_ROOT}/whisper.cpp/models/download-ggml-model.sh"

# Colors
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

check_dependencies() {
    if [ ! -f "$DOWNLOADER" ]; then
        echo -e "${RED}[ERROR]${NC} Whisper engine not found."
        echo "Please run ./setup.sh first."
        exit 1
    fi
}

# Helper to check status
get_status_label() {
    local model_name=$1
    if [ -f "${MODELS_DIR}/ggml-${model_name}.bin" ]; then
        echo -e "${GREEN}[INSTALLED]${NC}"
    else
        echo -e "${RED}[MISSING]${NC}"
    fi
}

toggle_model() {
    local model_name=$1
    local file_path="${MODELS_DIR}/ggml-${model_name}.bin"

    if [ -f "$file_path" ]; then
        # DELETE FLOW
        echo ""
        echo -e "${RED}Delete model '${model_name}'?${NC}"
        read -p "Type 'y' to confirm: " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            rm -f "$file_path"
            echo -e "${YELLOW}Model deleted.${NC}"
        else
            echo -e "${BLUE}Cancelled.${NC}"
        fi
    else
        # DOWNLOAD FLOW
        echo ""
        echo -e "${YELLOW}[ACTION]${NC} Downloading model: ${GREEN}${model_name}${NC}"
        # Execute inside whisper.cpp/models so files land in the right place
        cd "${MODELS_DIR}"
        bash download-ggml-model.sh "$model_name"
        cd "$SCRIPT_DIR" # Return to script dir
        echo -e "${GREEN}[SUCCESS]${NC} Model ready."
    fi
    echo ""
    read -p "Press Enter to continue..."
}

# Main Menu
check_dependencies
while true; do
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}       Whisper Model Manager            ${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Select a model to ${GREEN}Download${NC} or ${RED}Delete${NC}:"
    echo ""
    
    # Status Checks
    ST_TINY=$(get_status_label "tiny")
    ST_BASE=$(get_status_label "base")
    ST_SMALL=$(get_status_label "small")
    ST_MEDIUM=$(get_status_label "medium")
    ST_LARGE=$(get_status_label "large-v3-turbo")

    echo -e "  1) Tiny   $ST_TINY   (75MB)"
    echo -e "  2) Base   $ST_BASE   (142MB)"
    echo -e "  3) Small  $ST_SMALL   (466MB)"
    echo -e "  4) Medium $ST_MEDIUM   (1.5GB)"
    echo -e "  5) Large  $ST_LARGE   (1.6GB)"
    echo ""
    echo -e "  q) Back to Main Menu"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) toggle_model "tiny" ;;
        2) toggle_model "base" ;;
        3) toggle_model "small" ;;
        4) toggle_model "medium" ;;
        5) toggle_model "large-v3-turbo" ;;
        q|Q) exit 0 ;;
        *) echo "Invalid option." ; sleep 1 ;;
    esac
done