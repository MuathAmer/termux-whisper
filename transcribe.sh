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
             echo -e "${RED}[ERROR]${NC} 'Termux:API' not installed."
             echo "Please run 'pkg install termux-api' and install the Termux:API app."
             exit 1
        fi
        
        echo -e "${BLUE}[INFO]${NC} Opening system file picker..."
        INPUT_PATH="import_$(date +%s).tmp"
        termux-storage-get "$INPUT_PATH"
        
        # Check if file was actually created/not empty
        if [ ! -s "$INPUT_PATH" ]; then
            rm -f "$INPUT_PATH"
            INPUT_PATH=""
        fi

    # CASE B: Interactive TUI (Dialog)
    elif command -v dialog &> /dev/null; then
        INPUT_PATH=$(dialog --stdout --title "Select Audio File" --fselect "$HOME/" 14 60)

    # CASE C: Nothing available
    else
        echo -e "${BLUE}Usage:${NC} $0 [file_or_folder] [--model|-m model_name] [--subs] [--native]"
        echo -e "${YELLOW}Example:${NC} $0 /sdcard/Download/movie.mp4 --model base"
        echo -e "${YELLOW}Example:${NC} $0 --model base (opens picker using 'base' model)"
        echo ""
        echo -e "${RED}[ERROR]${NC} No file specified and no picker tools (dialog/termux-api) found."
        echo -e "Run ${GREEN}pkg install dialog${NC} for the best experience."
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