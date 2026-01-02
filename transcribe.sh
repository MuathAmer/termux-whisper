#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Path to the compiled binary inside the submodule
WHISPER_EXEC="./whisper.cpp/build/bin/whisper-cli"
MODELS_DIR="./whisper.cpp/models"

# Colors
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; NC='\033[0m'

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================

INPUT_PATH=""
MODEL_NAME="small"
GENERATE_SUBS=false
USE_NATIVE_PICKER=false
USE_DIALOG_PICKER=false

# Simple loop to handle positional args and flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --subs)
      GENERATE_SUBS=true
      shift # past argument
      ;;
    --native)
      USE_NATIVE_PICKER=true
      shift # past argument
      ;;
    --dialog)
      USE_DIALOG_PICKER=true
      shift # past argument
      ;;
    --model|-m)
      MODEL_NAME="$2"
      shift 2 # past argument and value
      ;;
    -*)
      echo "Unknown option $1"
      shift # past argument
      ;;
    *)
      if [ -z "$INPUT_PATH" ]; then
        INPUT_PATH="$1"
      elif [ "$MODEL_NAME" == "small" ]; then # Only override default if not already set
        MODEL_NAME="$1"
      fi
      shift # past argument
      ;;
  esac
done

MODEL_FILE="${MODELS_DIR}/ggml-${MODEL_NAME}.bin"
THREADS=4

# ==============================================================================
# CHECKS & INPUT HANDLING
# ==============================================================================

# 1. If no input file provided, try to pick one
if [ -z "$INPUT_PATH" ]; then

    # CASE A: Native Android Picker requested
    if [ "$USE_NATIVE_PICKER" = true ]; then
        if ! command -v termux-storage-get &> /dev/null; then
             echo -e "${RED}[ERROR]${NC} 'Termux:API' not installed or not found."
             echo "Please run 'pkg install termux-api' and install the Termux:API app from Play Store/F-Droid."
             exit 1
        fi
        
        echo -e "${BLUE}[INFO]${NC} Opening system file picker via 'termux-storage-get'..."
        # Create a unique temp filename to store the imported content
        INPUT_PATH="import_$(date +%s).tmp"
        
        # Execute termux-storage-get to pull file content into INPUT_PATH
        # Note: This is asynchronous on some devices/API levels, so we must wait.
        termux-storage-get "$INPUT_PATH"
        
        echo -e "${YELLOW}[ACTION]${NC} Please select a file in the Android picker that appeared."
        read -p "Press [Enter] once you have selected the file... "

        # Check if file was actually created/not empty
        if [ ! -s "$INPUT_PATH" ]; then
            echo -e "${YELLOW}[WARN]${NC} No file selected or file is empty."
            rm -f "$INPUT_PATH"
            INPUT_PATH=""
        else
            echo -e "${GREEN}[SUCCESS]${NC} File imported successfully."
        fi

    # CASE B: Interactive TUI (Dialog) - Only if explicitly requested
    elif [ "$USE_DIALOG_PICKER" = true ]; then
        if command -v dialog &> /dev/null; then
             echo -e "${BLUE}[INFO]${NC} Launching file browser..."
             INPUT_PATH=$(dialog --stdout --title "Select Audio File" --fselect "$HOME/" 14 60)
        else
             echo -e "${RED}[ERROR]${NC} 'dialog' package not installed."
             echo "Run 'pkg install dialog' to use the text-based picker."
             exit 1
        fi

    # CASE C: Nothing available
    else
        echo -e "${BLUE}Usage:${NC} $0 [file_or_folder] [options]"
        echo ""
        echo "Options:"
        echo -e "  --model, -m [name]  Choose model (tiny, base, small, medium, large)"
        echo -e "  --subs              Generate .srt and .vtt subtitles"
        echo -e "  --native            Use Android System File Picker"
        echo -e "  --dialog            Use Terminal File Browser (requires 'dialog')"
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo -e "  $0 /sdcard/Download/voice_memo.m4a --model base"
        echo -e "  $0 --native --model small"
        echo -e "  $0 --dialog"
        exit 1
    fi

    # Handle cancellation (User opened picker but didn't select anything)
    if [ -z "$INPUT_PATH" ]; then
        echo -e "${YELLOW}Selection cancelled.${NC}"
        exit 0
    fi
fi

# 2. Check Requirements
if [ ! -f "$WHISPER_EXEC" ]; then
    echo -e "${RED}[ERROR]${NC} Engine not built. Run ./setup.sh first."
    exit 1
fi

if [ ! -f "$MODEL_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Model '${MODEL_NAME}' not found. Run ./models.sh"
    exit 1
fi

# ==============================================================================
# LOGIC
# ==============================================================================

transcribe_file() {
    local input_file="$1"
    local dir_path=$(dirname "$input_file")
    local filename=$(basename "$input_file")
    local filename_no_ext="${filename%.*}"
    
    # Temp WAV (16kHz required)
    # Note: We use a hidden file .name.wav to avoid clutter
    local temp_wav="${dir_path}/.${filename_no_ext}_temp_16k.wav"
    
    # DETERMINE OUTPUT PATH
    local output_base=""
    
    if [[ "$USE_NATIVE_PICKER" == true || "$filename" == import_*.tmp ]]; then
        # If using native picker, the input is a temp file with no meaningful name/path.
        # We save results to a dedicated "Transcripts" folder in Downloads.
        local dl_dir="/sdcard/Download/Termux-Whisper"
        mkdir -p "$dl_dir"
        
        # Use timestamp + model name
        local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
        output_base="${dl_dir}/Transcript_${timestamp}_${MODEL_NAME}"
        
        echo -e "${BLUE}[INFO]${NC} Native Picker used. Saving to: ${YELLOW}${dl_dir}/${NC}"
    else
        # Standard behavior: Save next to original file
        output_base="${dir_path}/${filename_no_ext}_TRANSCRIPT"
    fi

    echo -e "${YELLOW}[BUSY]${NC} Processing: $filename"

    # Convert
    ffmpeg -nostdin -y -i "$input_file" -ar 16000 -ac 1 -c:a pcm_s16le "$temp_wav" -v quiet
    if [ $? -ne 0 ]; then
        echo -e "${RED}[FAIL]${NC} FFmpeg conversion failed."
        return
    fi

    # Build Command
    local cmd_args=(
        "-m" "$MODEL_FILE"
        "-f" "$temp_wav"
        "-t" "$THREADS"
        "-otxt"
        "-of" "$output_base"
    )

    if [ "$GENERATE_SUBS" = true ]; then
        cmd_args+=("-osrt" "-ovtt")
    fi

    # Run Whisper
    "$WHISPER_EXEC" "${cmd_args[@]}" > /dev/null 2>&1

    # Cleanup
    rm "$temp_wav"
    
    # If using native picker, delete the imported temp file too
    if [[ "$filename" == import_*.tmp ]]; then
        rm "$input_file"
    fi
    
    echo -e "${GREEN}[DONE]${NC} Saved: ${output_base}.txt"
}

if [ -f "$INPUT_PATH" ]; then
    transcribe_file "$INPUT_PATH"
elif [ -d "$INPUT_PATH" ]; then
    echo -e "${BLUE}Batch processing directory...${NC}"
    shopt -s nocaseglob nullglob
    for f in "$INPUT_PATH"/*.{opus,mp3,wav,m4a,flac,ogg,aac,mp4,mkv,avi,mov}; do
        transcribe_file "$f"
    done
else
    echo -e "${RED}[ERROR]${NC} Invalid path: $INPUT_PATH"
fi