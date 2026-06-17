#!/bin/bash

# Path to the TLP configuration file
CONFIG_FILE="/etc/tlp.conf"

# Define the two threshold sets
START1=90
STOP1=95

START2=75
STOP2=80

# Check current value of START_CHARGE_THRESH_BAT0
CURRENT_START=$(grep -oP '^START_CHARGE_THRESH_BAT0=\K\d+' "$CONFIG_FILE")

if [ "$CURRENT_START" == "$START1" ]; then
    NEW_START=$START2
    NEW_STOP=$STOP2
    MODE="Battery Health (75/80)"
else
    NEW_START=$START1
    NEW_STOP=$STOP1
    MODE="Full Charge (90/95)"
fi

echo "Setting TLP thresholds to $MODE..."

# Perform the replacement using sudo and sed
# We use sudo tee or sudo sed -i. sed -i with sudo is standard.
sudo sed -i "s/^START_CHARGE_THRESH_BAT0=.*/START_CHARGE_THRESH_BAT0=$NEW_START/" "$CONFIG_FILE"
sudo sed -i "s/^STOP_CHARGE_THRESH_BAT0=.*/STOP_CHARGE_THRESH_BAT0=$NEW_STOP/" "$CONFIG_FILE"

# Apply the changes
echo "Applying TLP settings..."
sudo tlp start

echo "Success: Thresholds set to $NEW_START/$NEW_STOP."
