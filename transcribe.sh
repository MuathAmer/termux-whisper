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

# Simple loop to handle positional args and flags
while [[ $# -gt 0 ]]; do
  case $1 in
    --subs)
      GENERATE_SUBS=true
      shift # past argument
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
# CHECKS
# ==============================================================================

if [ -z "$INPUT_PATH" ]; then
    echo -e "${BLUE}Usage:${NC} $0 <file_or_folder> [model_name] [--subs]"
    echo -e "${YELLOW}Example:${NC} $0 /sdcard/Download/movie.mp4 --subs"
    echo -e "${YELLOW}Example:${NC} $0 /sdcard/Download/ small --subs"
    exit 1
fi

if [ ! -f "$WHISPER_EXEC" ]; then
    echo -e "${RED}[ERROR]${NC} Engine not built."
    echo "Run ./setup.sh first."
    exit 1
fi

if [ ! -f "$MODEL_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} Model '${MODEL_NAME}' not found."
    echo "Run ./models.sh to download it."
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
    local temp_wav="${dir_path}/.${filename_no_ext}_temp_16k.wav"
    local output_base="${dir_path}/${filename_no_ext}_TRANSCRIPT"

    echo -e "${YELLOW}[BUSY]${NC} Processing: $filename"

    # Convert
    ffmpeg -nostdin -y -i "$input_file" -ar 16000 -ac 1 -c:a pcm_s16le "$temp_wav" -v quiet
    if [ $? -ne 0 ]; then
        echo -e "${RED}[FAIL]${NC} FFmpeg conversion failed for $filename"
        return
    fi

    # Build Command
    # Always output text (-otxt)
    local cmd_args=(
        "-m" "$MODEL_FILE"
        "-f" "$temp_wav"
        "-t" "$THREADS"
        "-otxt"
        "-of" "$output_base"
    )

    # Optional: Subtitles
    if [ "$GENERATE_SUBS" = true ]; then
        cmd_args+=("-osrt" "-ovtt")
        echo -e "${BLUE}[INFO]${NC} Generating subtitles..."
    fi

    # Run Whisper
    "$WHISPER_EXEC" "${cmd_args[@]}" > /dev/null 2>&1

    # Cleanup
    rm "$temp_wav"
    
    if [ "$GENERATE_SUBS" = true ]; then
         echo -e "${GREEN}[DONE]${NC} Saved: ${output_base}.txt (+ .srt/.vtt)"
    else
         echo -e "${GREEN}[DONE]${NC} Saved: ${output_base}.txt"
    fi
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