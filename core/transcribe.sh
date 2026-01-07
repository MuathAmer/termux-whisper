#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Resolve script directory for robust relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Path to the compiled binary inside the submodule
WHISPER_EXEC="${PROJECT_ROOT}/whisper.cpp/build/bin/whisper-cli"
MODELS_DIR="${PROJECT_ROOT}/whisper.cpp/models"

# Supported formats
SUPPORTED_EXTS="opus mp3 wav m4a flac ogg aac mp4 mkv avi mov"

# Colors (Safe definition)
if [ -t 1 ]; then
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    RED=$(tput setaf 1)
    BLUE=$(tput setaf 4)
    NC=$(tput sgr0)
else
    GREEN=""
    YELLOW=""
    RED=""
    BLUE=""
    NC=""
fi

# Load User Configuration
CONFIG_FILE="$HOME/.termux_whisper_config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================

INPUT_PATH=""
MODEL_NAME="small"
GENERATE_SUBS=false
USE_SYS_PICKER=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --subs)
      GENERATE_SUBS=true
      shift # past argument
      ;;
    --file-picker)
      USE_SYS_PICKER=true
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
# CLEANUP TRAP
# ==============================================================================

# Global temp files to be cleaned up
TEMP_FILES=()

cleanup() {
    for f in "${TEMP_FILES[@]}"; do
        if [ -f "$f" ]; then
            rm -f "$f"
        fi
    done
}
trap cleanup EXIT INT TERM

# ==============================================================================
# CHECKS & INPUT HANDLING
# ==============================================================================

if [ -z "$INPUT_PATH" ]; then

    # CASE A: Native Android Picker requested
    if [ "$USE_SYS_PICKER" = true ]; then
        if ! command -v termux-storage-get &> /dev/null; then
             echo -e "${RED}[ERROR]${NC} 'Termux:API' not installed or not found."
             echo "Please run 'pkg install termux-api' and install the Termux:API app from Play Store/F-Droid."
             exit 1
        fi
        
        echo ""
        echo -e "${BLUE}[INFO]${NC} Opening system file picker via 'termux-storage-get'..."
        
        # Use mktemp for safety
        INPUT_PATH=$(mktemp --suffix=.tmp)
        TEMP_FILES+=("$INPUT_PATH")
        
        # Execute termux-storage-get to pull file content into INPUT_PATH
        # Note: This is asynchronous on some devices/API levels, so we must wait.
        termux-storage-get "$INPUT_PATH"
        
        echo -e "${YELLOW}[ACTION]${NC} Please select a file in the Android picker that appeared."
        read -p "Press [Enter] once you have selected the file... "
        echo ""

        # Check if file was actually created/not empty
        if [ ! -s "$INPUT_PATH" ]; then
            echo -e "${YELLOW}[WARN]${NC} No file selected or file is empty."
            # Cleanup handled by trap, but we reset PATH for logic flow
            INPUT_PATH=""
        else
            echo -e "${BLUE}[INFO]${NC} Detecting file format..."
            
            # 1. Check for audio stream
            # We explicitly ask only for the stream type of audio streams.
            has_audio=$(ffprobe -v error -select_streams a -show_entries stream=codec_type -of default=noprint_wrappers=1:nokey=1 "$INPUT_PATH" 2>/dev/null)
            
            if [[ "$has_audio" != *"audio"* ]]; then
                echo -e "${RED}[ERROR]${NC} The selected file does not contain a valid audio stream."
                exit 1
            fi

            # 2. Get container format
            # We separately ask for the format name.
            format_info=$(ffprobe -v error -show_entries format=format_name -of default=noprint_wrappers=1:nokey=1 "$INPUT_PATH" 2>/dev/null)
            
            # Extract first format name (ffprobe sometimes returns "mov,mp4,m4a...")
            raw_fmt=$(echo "$format_info" | head -n 1 | cut -d',' -f1)
            
            # Mapping common ffprobe format names to extensions
            ext="$raw_fmt"
            [[ "$raw_fmt" == "matroska" ]] && ext="mkv"
            [[ "$raw_fmt" == "mov" ]] && ext="m4a" # common for m4a
            
            # Validate extension
            is_supported=false
            for s_ext in $SUPPORTED_EXTS; do
                if [[ "$ext" == "$s_ext" || "$raw_fmt" == *"$s_ext"* ]]; then
                    is_supported=true
                    ext="$s_ext"
                    break
                fi
            done

            if [ "$is_supported" = false ]; then
                echo -e "${RED}[ERROR]${NC} Unsupported format: $raw_fmt"
                exit 1
            fi

            # Rename to preserve extension
            # We create a NEW temp file with the correct extension
            new_path="${INPUT_PATH%.*}.${ext}"
            mv "$INPUT_PATH" "$new_path"
            
            # Update INPUT_PATH and tracking array
            # Remove old path from array (it's gone)
            TEMP_FILES=(${TEMP_FILES[@]/$INPUT_PATH})
            INPUT_PATH="$new_path"
            TEMP_FILES+=("$INPUT_PATH")
            
            echo -e "${GREEN}[SUCCESS]${NC} File imported: ${ext^^} format detected."
        fi

    # CASE B: Nothing available
    else
        echo -e "${BLUE}Usage:${NC} $0 [file_or_folder] [options]"
        echo ""
        echo "Options:"
        echo -e "  --model, -m [name]  Choose model (tiny, base, small, medium, large)"
        echo -e "  --subs              Generate .srt and .vtt subtitles"
        echo -e "  --file-picker       Use Android System File Picker"
        echo ""
        echo -e "${YELLOW}Examples:${NC}"
        echo -e "  $0 /sdcard/Download/voice_memo.m4a --model base"
        echo -e "  $0 --file-picker --model small"
        exit 1
    fi

    # Handle cancellation (User opened picker but didn't select anything)
    if [ -z "$INPUT_PATH" ]; then
        echo -e "${YELLOW}Selection cancelled.${NC}"
        exit 0
    fi
fi

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

show_post_actions() {
    local out_file="$1"
    
    # Dependencies check
    local has_dialog=$(command -v dialog)
    local has_open=$(command -v termux-open)
    local has_clip=$(command -v termux-clipboard-set)
    local has_share=$(command -v termux-share)

    # Fallback if dialog is missing
    if [ -z "$has_dialog" ]; then
        if [ -n "$has_open" ]; then
            echo ""
            read -p "Open transcript? (y/N): " choice
            [[ "$choice" =~ ^[Yy]$ ]] && termux-open "$out_file"
        fi
        return
    fi

    # Interactive Loop
    while true; do
        exec 3>&1
        selection=$(dialog --title "Transcription Complete" \
                           --clear \
                           --cancel-label "Exit" \
                           --menu "File: $(basename "$out_file")" 12 50 4 \
                           1 "Open File" \
                           2 "Copy to Clipboard" \
                           3 "Share File" \
                           4 "Main Menu / Exit" \
                           2>&1 1>&3)
        exit_code=$?
        exec 3>&-

        # Handle Exit/Cancel
        if [ $exit_code -ne 0 ] || [ "$selection" == "4" ]; then
            break
        fi

        case $selection in
            1) 
                if [ -n "$has_open" ]; then
                    termux-open "$out_file"
                else
                    dialog --msgbox "Error: 'termux-open' not found." 6 40
                fi
                ;;
            2) 
                if [ -n "$has_clip" ]; then
                    cat "$out_file" | termux-clipboard-set
                    dialog --msgbox "Copied to clipboard!" 6 30
                else
                    dialog --msgbox "Error: Termux:API not installed." 6 40
                fi
                ;;
            3) 
                if [ -n "$has_share" ]; then
                    termux-share -a send "$out_file"
                else
                    dialog --msgbox "Error: Termux:API not installed." 6 40
                fi
                ;;
        esac
    done
}

transcribe_file() {
    local input_file="$1"
    local interactive="${2:-true}"
    local dir_path=$(dirname "$input_file")
    local filename=$(basename "$input_file")
    local filename_no_ext="${filename%.*}"
    
    # Create a safe temp file for WAV conversion
    # We use mktemp to avoid collisions and track it for cleanup
    local temp_wav=$(mktemp --suffix=.wav)
    TEMP_FILES+=("$temp_wav")
    
    # DETERMINE OUTPUT PATH
    local output_base=""
    
    if [[ "$USE_SYS_PICKER" == true || "$filename" == *tmp* ]]; then
        # If using native picker, the input is a temp file.
        # We save results to a dedicated "Transcripts" folder in Downloads.
        local dl_dir="/sdcard/Download/Termux-Whisper"
        mkdir -p "$dl_dir"
        
        # Use timestamp + model name
        local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
        output_base="${dl_dir}/Transcript_${timestamp}_${MODEL_NAME}"
        
        echo ""
        echo -e "${BLUE}[INFO]${NC} Native Picker used. Saving to: ${YELLOW}${dl_dir}/${NC}"
    else
        # Standard behavior: Save next to original file
        output_base="${dir_path}/${filename_no_ext}_TRANSCRIPT"
    fi

    echo ""
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

    if [ -n "$DEFAULT_LANG" ] && [ "$DEFAULT_LANG" != "auto" ]; then
        cmd_args+=("-l" "$DEFAULT_LANG")
    fi

    if [ "$GENERATE_SUBS" = true ]; then
        cmd_args+=("-osrt" "-ovtt")
    fi

    # Run Whisper
    # We do NOT silence stdout/stderr so the user can see progress (timestamps/segments)
    echo ""
    echo -e "${BLUE}[INFO]${NC} Transcribing... (Live output below)"
    echo "----------------------------------------"
    "$WHISPER_EXEC" "${cmd_args[@]}" 
    echo "----------------------------------------"

    # Cleanup is handled by trap
    
    echo ""
    echo -e "${GREEN}[DONE]${NC} Saved: ${output_base}.txt"
    if [ "$GENERATE_SUBS" = true ]; then
        echo -e "${GREEN}[DONE]${NC} Saved: ${output_base}.srt"
        echo -e "${GREEN}[DONE]${NC} Saved: ${output_base}.vtt"
    fi

    # POST-TRANSCRIPTION ACTIONS
    if [ "$interactive" = true ]; then
        show_post_actions "${output_base}.txt"
    fi
}

if [ -f "$INPUT_PATH" ]; then
    transcribe_file "$INPUT_PATH" true
elif [ -d "$INPUT_PATH" ]; then
    echo -e "${BLUE}Batch processing directory...${NC}"
    shopt -s nocaseglob nullglob
    
    # Construct glob from supported extensions
    pattern_list=""
    for ext in $SUPPORTED_EXTS; do
        pattern_list+="$INPUT_PATH/*.$ext "
    done
    
    for f in $pattern_list; do
        transcribe_file "$f" false
    done
else
    echo -e "${RED}[ERROR]${NC} Invalid path: $INPUT_PATH"
fi