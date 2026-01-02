#!/bin/bash

# Termux Whisper Setup Script
# Installs dependencies, clones the engine, and builds it.

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Resolve Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"


echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Termux Whisper Installer            ${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. Update and Install Dependencies
echo -e "\n${YELLOW}[1/4] Installing system dependencies...${NC}"
pkg update -y
pkg install -y git cmake clang ffmpeg wget dialog termux-api

# 2. Setup Storage
echo -e "\n${YELLOW}[2/4] Setting up storage access...${NC}"
if [ ! -d ~/storage ]; then
    echo "Please tap 'Allow' on the permission popup if it appears."
    termux-setup-storage
    sleep 2
else
    echo "Storage already configured."
fi

# 3. Clone/Pull Whisper.cpp
echo -e "\n${YELLOW}[3/4] Fetching Whisper engine...${NC}"
cd "$PROJECT_ROOT"
if [ -d "whisper.cpp" ]; then
    echo "Directory exists. Updating..."
    cd whisper.cpp
    git pull
    cd ..
else
    git clone https://github.com/ggerganov/whisper.cpp.git
fi

# 4. Build
echo -e "\n${YELLOW}[4/4] Compiling engine (this may take a minute)...${NC}"
cd "$PROJECT_ROOT/whisper.cpp"
# Clean previous build to ensure freshness
rm -rf build
cmake -B build
cmake --build build -j --config Release

if [ $? -eq 0 ]; then
    # 5. Create Alias
    echo -e "\n${YELLOW}[5/5] Creating shortcut...${NC}"
    
    MENU_SCRIPT="${PROJECT_ROOT}/menu.sh"
    BASHRC="$HOME/.bashrc"
    
    # Check if alias exists
    if grep -q "alias whisper=" "$BASHRC" 2>/dev/null; then
        echo "Shortcut 'whisper' already exists."
    else
        echo "alias whisper=\"bash '$MENU_SCRIPT'\"" >> "$BASHRC"
        echo "Added 'whisper' alias to ~/.bashrc"
    fi

    echo -e "\n${GREEN}[SUCCESS] Installation Complete!${NC}"
    echo -e "Restart Termux, then type ${YELLOW}whisper${NC} to start."
    echo -e "Or run manually: ${YELLOW}./menu.sh${NC}"
else
    echo -e "\n${RED}[ERROR] Compilation failed.${NC}"
fi
