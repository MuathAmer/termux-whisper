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

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================

INPUT_PATH=""
MODEL_NAME="small"
GENERATE_TXT=true
GENERATE_SUBS=false
GENERATE_LRC=false
USE_SYS_PICKER=false
CLI_OVERRIDE=false

# Load User Configuration (Overrides defaults)
CONFIG_FILE="$HOME/.termux_whisper_config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

show_usage() {
    echo -e "${BLUE}Usage:${NC} whisper [file_or_folder] [options]"
    echo ""
    echo "Options:"
    echo -e "  -h, --help          Show this help message"
    echo -e "  --model, -m [name]  Choose model (tiny, base, small, medium, large)"
    echo -e "  --txt               Generate text transcript (default)"
    echo -e "  --no-txt            Disable text transcript"
    echo -e "  --subs              Generate .srt and .vtt subtitles"
    echo -e "  --no-subs           Disable subtitle generation"
    echo -e "  --lrc               Generate .lrc lyrics"
    echo -e "  --no-lrc            Disable lyrics generation"
    echo -e "  --file-picker       Launch Android System File Picker"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  whisper song.mp3 --lrc --no-txt"
    echo -e "  whisper video.mp4 --subs"
    echo -e "  whisper folder/ --no-subs"
    exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      show_usage
      ;;
    --txt)
      GENERATE_TXT=true
      CLI_OVERRIDE=true
      shift # past argument
      ;;
    --no-txt)
      GENERATE_TXT=false
      CLI_OVERRIDE=true
      shift # past argument
      ;;
    --subs)
      GENERATE_SUBS=true
      CLI_OVERRIDE=true
      shift # past argument
      ;;
    --no-subs)
      GENERATE_SUBS=false
      CLI_OVERRIDE=true
      shift # past argument
      ;;
    --lrc)
      GENERATE_LRC=true
      CLI_OVERRIDE=true
      shift # past argument
      ;;
    --no-lrc)
      GENERATE_LRC=false
      CLI_OVERRIDE=true
      shift # past argument
      ;;
    --file-picker)
      USE_SYS_PICKER=true
      shift # past argument
      ;;
    --model|-m)
      MODEL_NAME="$2"
      CLI_OVERRIDE=true
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
    echo -e "${YELLOW}[WARN]${NC} Model '${MODEL_NAME}' not found."
    read -p "Download it now? (y/n): " confirm_dl
    
    if [[ "$confirm_dl" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}[INFO]${NC} Downloading model..."
        
        # Save current dir to return later (though script exits soon, good practice)
        PUSH_DIR=$(pwd)
        cd "${MODELS_DIR}" || exit 1
        
        # Download
        if bash download-ggml-model.sh "$MODEL_NAME"; then
            echo -e "${GREEN}[SUCCESS]${NC} Download complete."
        else
            echo -e "${RED}[ERROR]${NC} Download failed."
            cd "$PUSH_DIR"
            exit 1
        fi
        cd "$PUSH_DIR"
        
        # Re-check
        if [ ! -f "$MODEL_FILE" ]; then
             echo -e "${RED}[ERROR]${NC} Model file still missing after download."
             exit 1
        fi
    else
        echo -e "${RED}[ERROR]${NC} Cannot proceed without model."
        exit 1
    fi
fi

# ==============================================================================
# LOGIC
# ==============================================================================

show_post_actions() {
    local out_file="$1"
    local has_open=$(command -v termux-open)
    local has_clip=$(command -v termux-clipboard-set)
    local has_share=$(command -v termux-share)

    while true; do
        clear
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}       Transcription Complete           ${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "File: ${YELLOW}$(basename "$out_file")${NC}"
        echo ""
        echo -e "${YELLOW}Actions:${NC}"
        echo -e "  ${GREEN}1)${NC} Open Transcript"
        echo -e "  ${GREEN}2)${NC} Copy to Clipboard"
        echo -e "  ${GREEN}3)${NC} Share Transcript"
        echo -e "  ${GREEN}4)${NC} Main Menu / Exit"
        echo ""
        read -p "Select option: " selection

        case $selection in
            1) 
                if [ -n "$has_open" ]; then
                    termux-open "$out_file"
                    echo -e "${GREEN}Opened.${NC}"
                else
                    echo -e "${RED}Error: 'termux-open' not found.${NC}"
                    read -p "Press Enter..."
                fi
                ;;
            2)
                if [ -n "$has_clip" ]; then
                    cat "$out_file" | termux-clipboard-set
                    echo -e "${GREEN}Copied to clipboard!${NC}"
                    read -p "Press Enter..."
                else
                    echo -e "${RED}Error: Termux:API not installed.${NC}"
                    read -p "Press Enter..."
                fi
                ;;
            3)
                if [ -n "$has_share" ]; then
                    termux-share -a send "$out_file"
                    echo -e "${GREEN}Sharing...${NC}"
                else
                    echo -e "${RED}Error: Termux:API not installed.${NC}"
                    read -p "Press Enter..."
                fi
                ;;
            4)
                break
                ;;
            *)
                echo -e "${RED}Invalid selection.${NC}"
                read -p "Press Enter..."
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

    # Output selection
    if [ "$GENERATE_TXT" = false ] && [ "$GENERATE_SUBS" = false ] && [ "$GENERATE_LRC" = false ]; then
        echo -e "${RED}[ERROR]${NC} No output format selected!"
        echo "Please enable at least one: --txt, --subs, or --lrc"
        return
    fi

    if [ "$GENERATE_TXT" = true ]; then
        cmd_args+=("-otxt")
    fi

    if [ "$GENERATE_SUBS" = true ]; then
        cmd_args+=("-osrt" "-ovtt")
    fi

    if [ "$GENERATE_LRC" = true ]; then
        cmd_args+=("-olrc")
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
    if [ "$GENERATE_TXT" = true ]; then
        echo -e "${GREEN}[DONE]${NC} Saved: ${output_base}.txt"
    fi
    if [ "$GENERATE_SUBS" = true ]; then
        echo -e "${GREEN}[DONE]${NC} Saved: ${output_base}.srt"
        echo -e "${GREEN}[DONE]${NC} Saved: ${output_base}.vtt"
    fi
    if [ "$GENERATE_LRC" = true ]; then
        echo -e "${GREEN}[DONE]${NC} Saved: ${output_base}.lrc"
    fi

    # POST-TRANSCRIPTION ACTIONS
    if [ "$interactive" = true ]; then
        show_post_actions "${output_base}.txt"
    fi
}

# ==============================================================================
# PRE-FLIGHT CHECK
# ==============================================================================

ensure_model_exists() {
    local m_name="$1"
    local m_file="${MODELS_DIR}/ggml-${m_name}.bin"
    
    if [ ! -f "$m_file" ]; then
        echo -e "${YELLOW}[WARN]${NC} Model '${m_name}' not found."
        read -p "Download now? (y/n): " dl_choice
        if [[ "$dl_choice" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Downloading...${NC}"
            PUSH_DIR=$(pwd)
            cd "${MODELS_DIR}" || return 1
            if bash download-ggml-model.sh "$m_name"; then
                echo -e "${GREEN}Success.${NC}"
            else
                echo -e "${RED}Failed.${NC}"
                cd "$PUSH_DIR"
                return 1
            fi
            cd "$PUSH_DIR"
        else
            return 1
        fi
    fi
    return 0
}

pre_flight_check() {
  # Don't check if running non-interactively (e.g. forced via flag)
  if [ "$CLI_OVERRIDE" = true ]; then return; fi

  local timer=20
  while [ $timer -gt 0 ]; do
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}       Transcription Preparation        ${NC}"
    echo -e "${BLUE}========================================${NC}"
    
    # Display Info
    if [ -d "$INPUT_PATH" ]; then
      local count=$(ls -1 "$INPUT_PATH" | wc -l)
      echo -e "Target:  ${YELLOW}[Folder] $INPUT_PATH ($count files)${NC}"
    else
      echo -e "Target:  ${YELLOW}$(basename "$INPUT_PATH")${NC}"
    fi
    
    echo -e "Model:   ${GREEN}$MODEL_NAME${NC}"
    
    # Text Status
    if [ "$GENERATE_TXT" = true ]; then T_STAT="${GREEN}ON${NC}"; else T_STAT="${RED}OFF${NC}"; fi
    echo -e "Text:    $T_STAT"

    # Subs Status
    if [ "$GENERATE_SUBS" = true ]; then S_STAT="${GREEN}ON${NC}"; else S_STAT="${RED}OFF${NC}"; fi
    echo -e "Subs:    $S_STAT"
    
    # LRC Status
    if [ "$GENERATE_LRC" = true ]; then L_STAT="${GREEN}ON${NC}"; else L_STAT="${RED}OFF${NC}"; fi
    echo -e "Lyrics:  $L_STAT"
    
    echo -e "----------------------------------------"
    echo -e "[Enter]  Start Now"
    echo -e "[T]      Toggle Text (.txt)"
    echo -e "[S]      Toggle Subtitles (.srt/.vtt)"
    echo -e "[L]      Toggle Lyrics (.lrc)"
    echo -e "[M]      Change Model"
    echo -e "[Q]      Cancel"
    echo ""
    echo -e "${YELLOW}Auto-starting in $timer seconds...${NC}"

    # Non-blocking read
    read -t 1 -n 1 key
    if [ $? -eq 0 ]; then
      case "$key" in
        t|T)
          if [ "$GENERATE_TXT" = true ]; then GENERATE_TXT=false; else GENERATE_TXT=true; fi
          ;;
        s|S) 
          if [ "$GENERATE_SUBS" = true ]; then GENERATE_SUBS=false; else GENERATE_SUBS=true; fi 
          ;;
        l|L) 
          if [ "$GENERATE_LRC" = true ]; then GENERATE_LRC=false; else GENERATE_LRC=true; fi 
          ;;
        m|M)
          echo ""
          read -p "Enter model name (tiny/base/small/medium/large): " new_model
          if [ -n "$new_model" ]; then
            if ensure_model_exists "$new_model"; then
              MODEL_NAME="$new_model"
              MODEL_FILE="${MODELS_DIR}/ggml-${MODEL_NAME}.bin"
            else
              echo "Reverting to previous model."
              sleep 1
            fi
          fi
          ;;
        q|Q) 
          echo "Cancelled."
          exit 0 
          ;;
        "") 
          break ;; # Enter key
      esac
      # Reset timer on interaction to give more time? 
      # Or keep counting down? User said "Prompt at beginning", usually static.
      # Let's reset to 20 if they interact to prevent panic.
      timer=20 
    else
      ((timer--))
    fi
  done
  clear
}

# Run Pre-Flight Check if we have valid input
if [[ -f "$INPUT_PATH" || -d "$INPUT_PATH" ]]; then
    pre_flight_check
fi

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