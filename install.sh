#!/bin/bash

set -e
echo "Starting router installation..."

# : "${MEDIA_FILE_WORKSPACE:=media}"
# : "${MEDIA_APP_WORKSPACE:=apps}"
# echo "MEDIA_FILE_WORKSPACE is set to: $MEDIA_FILE_WORKSPACE"
# echo "MEDIA_APP_WORKSPACE is set to: $MEDIA_APP_WORKSPACE"

echo "Installing necessary packages..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install hostapd iptables-persistent git dhcpcd5 -y

# Check if Docker is installed, if not, install it
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker is NOT installed. Running installation script..."

    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh

    rm get-docker.sh

    sudo usermod -aG docker $USER
fi


grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
# To apply it immediately without reboot
sudo sysctl -w net.ipv4.ip_forward=1
# To apply it permanently
sudo sysctl -p

echo "Setup dhcpcd..."
sudo curl -fsSL https://raw.githubusercontent.com/Mrkisha/travel-router/refs/heads/master/dhcpcd.conf -o /etc/dhcpcd.conf
sudo systemctl enable dhcpcd
sudo systemctl restart dhcpcd

echo "Stup wlan1 up service..."
sudo curl -fsSL https://raw.githubusercontent.com/Mrkisha/travel-router/refs/heads/master/wlan1-up.service -o /etc/systemd/system/wlan1-up.service
sudo systemctl daemon-reload
sudo systemctl enable wlan1-up.service
