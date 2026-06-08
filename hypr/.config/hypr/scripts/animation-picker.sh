#!/bin/bash

ANIMATION_DIR="$HOME/.config/hypr/animations"
CURRENT_FILE="$ANIMATION_DIR/current.conf"

# List available animation profiles (without .conf extension)
PROFILES=$(ls -1 "$ANIMATION_DIR" | grep -v "current.conf" | sed 's/\.conf$//')

# Use wofi (or your preferred menu) to select a profile
SELECTED=$(echo "$PROFILES" | wofi -d -p "Select Animation Profile:")

if [ -n "$SELECTED" ]; then
    # Copy the selected profile to current.conf
    cp "$ANIMATION_DIR/$SELECTED.conf" "$CURRENT_FILE"
    
    # Send a notification
    notify-send -t 2000 "Hyprland" "Animation set to: $SELECTED"
fi
