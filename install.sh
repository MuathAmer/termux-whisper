#!/bin/bash

# Termux Whisper Bootstrap Installer
# This script is meant to be run via:
# curl -sL https://raw.githubusercontent.com/MuathAmer/termux-whisper/main/install.sh | bash

set -e

echo "Starting Termux Whisper installation..."

# 1. Install Git if missing
if ! command -v git &> /dev/null; then
    echo "Installing git..."
    pkg update -y
    pkg install -y git
fi

# 2. Clone or Update
TARGET_DIR="$HOME/termux-whisper"

if [ -d "$TARGET_DIR" ]; then
    echo "Updating existing installation in $TARGET_DIR..."
    cd "$TARGET_DIR"
    git pull
else
    echo "Cloning Termux Whisper to $TARGET_DIR..."
    git clone https://github.com/MuathAmer/termux-whisper.git "$TARGET_DIR"
    cd "$TARGET_DIR"
fi

# 3. Permissions
chmod +x *.sh

# 4. Trigger Setup
echo "Launching setup..."
chmod +x core/*.sh
./core/setup.sh
