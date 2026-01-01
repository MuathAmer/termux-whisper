#!/bin/bash

# Configuration
# Points to the official downloader inside the submodule
DOWNLOADER="./whisper.cpp/models/download-ggml-model.sh"

# Colors
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

check_dependencies() {
    if [ ! -f "$DOWNLOADER" ]; then
        echo -e "${RED}[ERROR]${NC} Whisper engine not found."
        echo "Please run ./setup.sh first."
        exit 1
    fi
}

download_model() {
    local model_name=$1
    echo -e "${YELLOW}[ACTION]${NC} Downloading model: ${GREEN}${model_name}${NC}"
    
    # Execute inside whisper.cpp/models so files land in the right place
    cd whisper.cpp/models
    bash download-ggml-model.sh "$model_name"
    cd ../..
    
    echo -e "${GREEN}[SUCCESS]${NC} Model ready."
    read -p "Press Enter to continue..."
}

# Main Menu
check_dependencies
while true; do
    clear
    echo -e "${BLUE}=== Whisper Model Manager ===${NC}"
    echo -e "  ${YELLOW}1)${NC} ${GREEN}Tiny${NC}   (Fastest, Low Accuracy, ~75MB)"
    echo -e "  ${YELLOW}2)${NC} ${GREEN}Base${NC}   (Balanced, ~142MB)"
    echo -e "  ${YELLOW}3)${NC} ${GREEN}Small${NC}  (Recommended for Pixel/Flagships, ~466MB)"
    echo -e "  ${YELLOW}4)${NC} ${GREEN}Medium${NC} (High Accuracy, Slow, ~1.5GB)"
    echo -e "  ${YELLOW}5)${NC} ${GREEN}Large${NC}  (Max Accuracy V3 Turbo, ~1.6GB)"
    echo ""
    echo -e "  ${YELLOW}9)${NC} Exit"
    echo ""
    read -p "Enter choice: " choice
    case $choice in
        1) download_model "tiny" ;;
        2) download_model "base" ;;
        3) download_model "small" ;;
        4) download_model "medium" ;;
        5) download_model "large-v3-turbo" ;;
        9) exit 0 ;;
        *) echo "Invalid option." ;;
    esac
done
