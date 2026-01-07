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

# Args
FORCE_REBUILD=false
if [[ "$1" == "--rebuild" ]]; then
    FORCE_REBUILD=true
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Termux Whisper Installer            ${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. Install Dependencies
echo -e "\n${YELLOW}[1/4] Checking dependencies...${NC}"
# We avoid 'pkg update' to be faster/idempotent. User should update their own system.
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
echo -e "\n${YELLOW}[4/4] Compiling engine...${NC}"
cd "$PROJECT_ROOT/whisper.cpp"

if [ "$FORCE_REBUILD" = true ]; then
    echo "Rebuild requested. Cleaning..."
    rm -rf build
fi

# CMake Logic: Incremental is default
cmake -B build
cmake --build build -j --config Release

if [ $? -eq 0 ]; then
    # 5. Create Global Command
    echo -e "\n${YELLOW}[5/5] Refreshing global 'whisper' command...${NC}"
    
    MENU_SCRIPT="${PROJECT_ROOT}/menu.sh"
    BIN_DIR="${PREFIX:-/data/data/com.termux/files/usr}/bin"
    TARGET_FILE="$BIN_DIR/whisper"

    if [ -d "$BIN_DIR" ]; then
        echo "#!/bin/bash" > "$TARGET_FILE"
        echo "exec bash \"$MENU_SCRIPT\" \"\$@\"" >> "$TARGET_FILE"
        chmod +x "$TARGET_FILE"
        echo "Installed to: $TARGET_FILE"
    else
        echo -e "${RED}[WARN]${NC} Could not find binary directory: $BIN_DIR"
    fi

    echo -e "\n${GREEN}[SUCCESS] Setup Complete!${NC}"
    echo -e "Run: ${YELLOW}whisper${NC}"
else
    echo -e "\n${RED}[ERROR] Compilation failed.${NC}"
    exit 1
fi
