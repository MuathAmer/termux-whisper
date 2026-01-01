#!/bin/bash

# Termux Whisper Setup Script
# Installs dependencies, clones the engine, and builds it.

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Termux Whisper Installer            ${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. Update and Install Dependencies
echo -e "\n${YELLOW}[1/4] Installing system dependencies...${NC}"
pkg update -y
pkg install -y git cmake clang ffmpeg wget

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
cd whisper.cpp
# Clean previous build to ensure freshness
rm -rf build
cmake -B build
cmake --build build -j --config Release

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}[SUCCESS] Installation Complete!${NC}"
    echo -e "Run ${YELLOW}./models.sh${NC} to download a model."
    echo -e "Run ${YELLOW}./transcribe.sh${NC} to start transcribing."
else
    echo -e "\n${RED}[ERROR] Compilation failed.${NC}"
fi
