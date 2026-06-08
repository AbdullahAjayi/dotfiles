#!/bin/bash

WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
APPLY_SCRIPT="$HOME/.config/hypr/scripts/apply-theme.sh"

# Get wallpapers and create pretty names for wofi
mapfile -t files < <(ls "$WALLPAPER_DIR")
pretty_names=()
for f in "${files[@]}"; do
    name="${f%.*}"
    pretty=$(echo "$name" | sed 's/[_-]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
    pretty_names+=("$pretty")
done

selected_pretty=$(printf "%s\n" "${pretty_names[@]}" | wofi --dmenu --prompt "Select Wallpaper")

if [[ -n "$selected_pretty" ]]; then
    selected=""
    for i in "${!pretty_names[@]}"; do
        if [[ "${pretty_names[$i]}" == "$selected_pretty" ]]; then
            selected="${files[$i]}"
            break
        fi
    done

    if [[ -n "$selected" ]]; then
        "$APPLY_SCRIPT" "$WALLPAPER_DIR/$selected"
    fi
fi
