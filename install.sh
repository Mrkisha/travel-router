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
sudo systemctl start wlan1-up.service


sudo tee /etc/hostapd/hostapd.conf > /dev/null << 'EOF'
interface=wlan1
driver=nl80211
ssid=Clifjumper2
wpa_passphrase=partizan
hw_mode=g
channel=6
ieee80211n=1
wmm_enabled=1
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

sudo systemctl disable --now dnsmasq

grep -qF 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' /etc/default/hostapd 2>/dev/null || echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee -a /etc/default/hostapd >/dev/null

sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd

echo "\e[36mThere should be 'type AP' in the text bellow!\e[0m"
iw dev wlan1 info


echo "Setting up iptables rules..."
sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
sudo iptables-save | sudo tee /etc/iptables/rules.v4
