#!/bin/bash

# Clear any previous Kitty images from the overlay
printf "\033_Ga=d,d=a;\033\\"

item="$1"

if [[ "$item" == *"[[ binary data"* ]]; then
    # It's an image. Extract it to a temporary file
    TMPFILE=$(mktemp --suffix=.png)
    echo -n "$item" | cliphist decode > "$TMPFILE"
    
    # Use Kitty's native graphics protocol for high-resolution rendering.
    # We constrain the size to the FZF preview window dimensions to prevent UI breakage.
    # The 'printf' at the top ensures that moving to a new item wipes the previous image.
    chafa -f kitty -s "${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}" --animate off --polite on "$TMPFILE"
    
    rm "$TMPFILE"
else
    # It's text. The 'printf' at the top already cleared any previous images.
    echo -n "$item" | cliphist decode
fi
