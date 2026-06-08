#!/bin/bash

# Kill any existing clipboard managers
pkill -f "wl-paste.*cliphist"
pkill wl-clip-persist

# Wait a moment
sleep 0.5

# Start clipboard watchers with FULL PATHS
/usr/bin/wl-paste --type text --watch /usr/bin/cliphist store &
/usr/bin/wl-paste --type image --watch /usr/bin/cliphist store &

# Start clipboard persistence with FULL PATH
/usr/bin/wl-clip-persist --clipboard regular &

# Log that we started
echo "Clipboard managers started at $(date)" >> /tmp/clipboard.log
