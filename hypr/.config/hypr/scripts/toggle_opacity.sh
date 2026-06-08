#!/bin/bash

# Configuration Paths
OPACITY_CONF="$HOME/.config/hypr/themes/opacity.conf"
STATE_FILE="$HOME/.config/hypr/.opacity_transparent"

# 1. State Logic (Atomic Toggle)
if [ -f "$STATE_FILE" ]; then
    # Currently TRANSPARENT -> Switch to OPAQUE
    rm "$STATE_FILE"
    ACTIVE=1.0
    INACTIVE=1.0
    MSG="OFF"
else
    # Currently OPAQUE -> Switch to TRANSPARENT
    touch "$STATE_FILE"
    ACTIVE=0.8
    INACTIVE=0.7
    MSG="ON"
fi

# 2. Persistence (Update Config File)
# We overwrite the entire file to ensure it's always valid
cat <<EOF > "$OPACITY_CONF"
decoration {
    active_opacity = $ACTIVE
    inactive_opacity = $INACTIVE
}
EOF

# 3. Application (Atomic Visual Update)
# Using --batch ensures both keywords are applied in a single compositor tick, preventing 'shake'
hyprctl --batch "keyword decoration:active_opacity $ACTIVE; keyword decoration:inactive_opacity $INACTIVE" >/dev/null

# 4. Feedback
notify-send "Opacity" "Transparency: $MSG" -i preferences-desktop-theme -t 1000
