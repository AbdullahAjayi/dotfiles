#!/bin/bash

# Define where to cache the icon database
CACHE_DIR="$HOME/.cache"
EMOJI_FILE="$CACHE_DIR/emojis.txt"

# If the database doesn't exist, download it (only happens once)
if [ ! -f "$EMOJI_FILE" ]; then
    mkdir -p "$CACHE_DIR"
    echo "Downloading icon database for the first time..."
    # We download a raw JSON file of all emojis and use jq to parse it into a clean list
    curl -sL "https://raw.githubusercontent.com/github/gemoji/master/db/emoji.json" | jq -r '.[] | "\(.emoji)  \(.description)  [\(.tags | join(", "))]"' | grep -v "^null" > "$EMOJI_FILE"
fi

# Launch the fzf picker
selected=$(cat "$EMOJI_FILE" | fzf \
    --layout=reverse \
    --prompt="Pick Icon ❯ " \
    --bind "enter:accept" \
    --color="border:#bd93f9,preview-border:#bd93f9,prompt:#50fa7b,pointer:#ff79c6")

# If the user selected something
if [ -n "$selected" ]; then
    # Extract exactly the first character (the emoji itself)
    emoji=$(echo "$selected" | awk '{print $1}')
    
    # Instantly copy it to the Wayland clipboard
    echo -n "$emoji" | wl-copy
    
    # If the user has 'wtype' installed, automatically type the emoji into the active window!
    if command -v wtype &> /dev/null; then
        wtype "$emoji"
    fi
fi
