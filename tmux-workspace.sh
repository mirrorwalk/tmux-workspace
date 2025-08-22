#!/usr/bin/env bash

# Config file path
CONFIG_DIR="$HOME/.config/tmux-workspace"
CONFIG_FILE="$CONFIG_DIR/config.sh"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found: $CONFIG_FILE"
    echo "Please create it with the appropriate settings."
    exit 1
fi

# Source the config file
source "$CONFIG_FILE"

# Default to showing root directories if not specified in config
SHOW_ROOT_DIRECTORIES=${SHOW_ROOT_DIRECTORIES:-true}

# Check if fzf is installed
if ! command -v fzf &> /dev/null; then
    echo "fzf is not installed. Please install it first."
    exit 1
fi

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    echo "tmux is not installed. Please install it first."
    exit 1
fi

# Collect all subdirectories from the root folders
SUBDIRS=()
for ROOT in "${!ROOT_FOLDERS[@]}"; do
    # Parse the configuration string "mindepth:maxdepth"
    CONFIG_STR="${ROOT_FOLDERS[$ROOT]}"
    IFS=':' read -r MIN_DEPTH MAX_DEPTH <<< "$CONFIG_STR"
    
    # Default values if not properly formatted
    MIN_DEPTH=${MIN_DEPTH:-0}
    MAX_DEPTH=${MAX_DEPTH:-1}
    
    if [ -d "$ROOT" ]; then
        # Use find with mindepth and maxdepth
        while IFS= read -r -d '' dir; do
            SUBDIRS+=("$dir")
        done < <(find "$ROOT" -mindepth "$MIN_DEPTH" -maxdepth "$MAX_DEPTH" -type d -print0)
    fi
done

# Remove duplicates and filter out subdirectories that are also root folders
FILTERED_SUBDIRS=()
declare -A SEEN_DIRS

for dir in "${SUBDIRS[@]}"; do
    # Skip if we've already seen this directory
    if [[ -n "${SEEN_DIRS[$dir]}" ]]; then
        continue
    fi
    
    # Mark this directory as seen
    SEEN_DIRS["$dir"]=1
    
        # Skip if this directory is itself a root folder
        if [[ -n "${ROOT_FOLDERS[$dir]}" ]]; then
            # Only include it if its own min depth == 0
            DIR_MIN_DEPTH="${ROOT_FOLDERS[$dir]%%:*}"
            if [[ "$DIR_MIN_DEPTH" -ne 0 ]]; then
                continue
            fi
        fi

    # Add to filtered list
    FILTERED_SUBDIRS+=("$dir")
done

# Use the filtered subdirectories
SUBDIRS=("${FILTERED_SUBDIRS[@]}")

# Exit if no subdirectories are found
if [ ${#SUBDIRS[@]} -eq 0 ]; then
    echo "No subdirectories found in the specified root folders."
    exit 1
fi

# Use fzf to select a subdirectory (full-screen by default)
SELECTED=$(printf "%s\n" "${SUBDIRS[@]}" | fzf --prompt="Select a directory to open in tmux: " --border)

# Exit if no directory is selected
if [ -z "$SELECTED" ]; then
    echo "No directory selected. Exiting."
    exit 0
fi

# Check if the selected directory exists
if [ ! -d "$SELECTED" ]; then
    echo "Selected directory does not exist: $SELECTED"
    exit 1
fi

# Get the directory name to use as the base tmux session name
SESSION_NAME=$(basename "$SELECTED")

# If a session with the same name exists, append a timestamp to avoid conflicts
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    SESSION_NAME="${SESSION_NAME}-$(date +%s)"
fi

# Check for custom window settings for the selected directory
WINDOWS_STR="${CUSTOM_WINDOWS[$SELECTED]}"
if [ -n "$WINDOWS_STR" ]; then
    IFS=':' read -r -a WINDOW_NAMES <<< "$WINDOWS_STR"
else
    WINDOW_NAMES=("main")
fi

# Create the session detached with the first window
FIRST_WINDOW_NAME="${WINDOW_NAMES[0]:-main}"
tmux new-session -d -s "$SESSION_NAME" -c "$SELECTED" -n "$FIRST_WINDOW_NAME"

# Add additional windows if any
for ((i=1; i<${#WINDOW_NAMES[@]}; i++)); do
    tmux new-window -t "$SESSION_NAME" -c "$SELECTED" -n "${WINDOW_NAMES[$i]}"
done

# If inside a tmux session, switch to the new session; otherwise, attach to it
if [ -n "$TMUX" ]; then
    tmux switch-client -t "$SESSION_NAME"
else
    tmux attach-session -t "$SESSION_NAME"
fi
