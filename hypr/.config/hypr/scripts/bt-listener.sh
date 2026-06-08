#!/bin/bash
# Listens for Bluetooth power-on events via D-Bus and triggers reconnect

stdbuf -oL dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Adapter1'" | \
while read -r line; do
    if [[ "$line" == *"string \"Powered\""* ]]; then
        found_powered=1
    elif [[ "$found_powered" == "1" ]]; then
        if [[ "$line" == *"boolean true"* ]]; then
            /home/abdullah/.config/hypr/scripts/bt-reconnect.sh nowait &
            found_powered=0
        elif [[ "$line" == *"boolean false"* ]]; then
            found_powered=0
        fi
    fi
done
