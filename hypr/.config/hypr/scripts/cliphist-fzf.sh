#!/bin/bash

# Get the selected item from cliphist using fzf in reverse layout
selected=$(cliphist list | fzf \
    --no-sort \
    --layout=reverse \
    --prompt="Clipboard ❯ " \
    --preview="~/.config/hypr/scripts/cliphist-preview.sh {}" \
    --preview-window=right:50%:wrap \
    --bind "enter:accept" \
    --color="border:#bd93f9,preview-border:#bd93f9,prompt:#50fa7b,pointer:#ff79c6")

# Exit if nothing selected
if [ -z "$selected" ]; then
    exit 0
fi

# Decode and copy to clipboard properly handling images
if [[ "$selected" == *"[[ binary data"* ]]; then
    echo -n "$selected" | cliphist decode | wl-copy --type image/png
else
    echo -n "$selected" | cliphist decode | wl-copy
fi
