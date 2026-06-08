#!/bin/bash
# Reconnect trusted Bluetooth devices after resume from sleep

# Skip sleep if called with 'nowait' (e.g. from the dbus listener)
if [ "$1" != "nowait" ]; then
    sleep 3  # Give bluetoothd time to fully initialize on system wake
fi

bluetoothctl -- power on

# Get all trusted devices and attempt to connect
bluetoothctl -- devices Trusted | awk '{print $2}' | while read -r mac; do
    echo "Attempting to connect: $mac"
    bluetoothctl -- connect "$mac" &
done
