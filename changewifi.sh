#!/bin/bash
# Usage: ./changewifi.sh [WIFINetwork] [Password]
# or set WIFI and PASSWORD in .env file or as environment variables

set -e

ENV_FILE=".env"

# Load env vars if file exists
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1091
  source "$ENV_FILE"
fi

# Use args if provided, else fall back to env vars
WIFI="${1:-${WIFI:-Hotel}}"
PASSWORD="${2:-${PASSWORD:-Room}}"

if [ -z "$WIFI" ] || [ -z "$PASSWORD" ]; then
  echo "Usage: $0 <WIFI Network> <Password>"
  echo "Or provide WIFI and PASSWORD in $ENV_FILE as:"
  echo "WIFI=your_wifi_ssid"
  echo "PASSWORD=your_wifi_password"
  exit 1
fi

sudo nmcli dev wifi connect "$WIFI" password "$PASSWORD" ifname wlan0
