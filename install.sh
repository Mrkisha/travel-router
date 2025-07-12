sudo apt-get update && sudo apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt install hostapd iptables-persistent git dhcpcd5 -y


curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

rm get-docker.sh

sudo usermod -aG docker $USER

grep -qxF 'net.ipv4.ip_forward=1' /etc/sysctl.conf || echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf
grep -qxF 'net.ipv4.conf.all.src_valid_mark=1' /etc/sysctl.conf || echo 'net.ipv4.conf.all.src_valid_mark=1' | sudo tee -a /etc/sysctl.conf
grep -qxF 'net.ipv6.conf.all.forwarding=1' /etc/sysctl.conf || echo 'net.ipv6.conf.all.forwarding=1' | sudo tee -a /etc/sysctl.conf


sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv4.conf.all.src_valid_mark=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1
sudo sysctl -p

grep -q '^\[keyfile\]' /etc/NetworkManager/NetworkManager.conf || echo -e '\n[keyfile]' | sudo tee -a /etc/NetworkManager/NetworkManager.conf; grep -q '^unmanaged-devices=interface-name:wlan1' /etc/NetworkManager/NetworkManager.conf || echo 'unmanaged-devices=interface-name:wlan1' | sudo tee -a /etc/NetworkManager/NetworkManager.conf

sudo systemctl restart NetworkManager


sudo tee /etc/hostapd/hostapd.conf > /dev/null << EOF
interface=wlan1
driver=nl80211
ssid=Clifjumper2
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=partizan
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
EOF

sudo tee /etc/hostapd/hostapd.conf > /dev/null << EOF
interface=wlan1
driver=nl80211
ssid=Clifjumper2
hw_mode=a
channel=36
wmm_enabled=1
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=partizan
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
country_code=RS
ieee80211n=1
ieee80211ac=1
ht_capab=[HT40+]
vht_capab=[SHORT-GI-80][RXLDPC][MAX-MPDU-7991]
vht_oper_chwidth=1
vht_oper_centr_freq_seg0_idx=42
EOF

grep -qF 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' /etc/default/hostapd 2>/dev/null || echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' | sudo tee -a /etc/default/hostapd >/dev/null

sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd

sudo tee /etc/dhcpcd.conf > /dev/null << EOF
interface wlan1
    static ip_address=192.168.50.1/24
    nohook wpa_supplicant
EOF

# sudo tee /etc/docker/daemon.json > /dev/null <<EOF
# {
#   "iptables": false
# }
# EOF

sudo systemctl restart docker

sudo tee /etc/systemd/system/fix-default-route.service > /dev/null <<EOF 
[Unit]
Description=Fix Default Route after Docker starts
After=docker.service
Wants=docker.service

[Service]
Type=oneshot
ExecStart=/sbin/ip route add default via 192.168.1.1 dev wlan0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable fix-default-route.service
sudo systemctl start fix-default-route.service

sudo rm -f /etc/docker/daemon.json
sudo rm -rf /etc/systemd/system/docker.service.d/
sudo systemctl daemon-reload
sudo systemctl restart docker

sudo tee /etc/systemd/system/wlan1-up.service > /dev/null <<EOF 
[Unit]
Description=Bring up wlan1 and assign static IP
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ip link set wlan1 up
ExecStart=/sbin/ip addr add 192.168.50.1/24 dev wlan1
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable wlan1-up.service
sudo systemctl start wlan1-up.service

sudo systemctl restart hostapd

sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
sudo iptables -A FORWARD -i wlan1 -o wg0 -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT

sudo iptables -A FORWARD -i wlan0 -o wg0 -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# internet from wlan0 i wlan1
# sudo iptables -A FORWARD -i wlan1 -o wlan0 -j ACCEPT
# sudo iptables -A FORWARD -i wlan0 -o wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT
# sudo iptables -t nat -C POSTROUTING -o wlan0 -j MASQUERADE || sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
# =========================

sudo netfilter-persistent save

tee ~/docker-compose.yaml > /dev/null <<EOF 
services:
  wireguard:
    image: linuxserver/wireguard:1.0.20210914
    container_name: wireguard
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=Europe/Berlin
    volumes:
      - .wireguard/config:/config
      - /lib/modules:/lib/modules
    restart: unless-stopped
    network_mode: "host"

  pihole:
    image: pihole/pihole:2025.06.2
    container_name: pihole
    environment:
      - TZ=Europe/Berlin
      - FTLCONF_webserver_api_password=homelab
      # Config file in pihole is /etc/pihole/pihole.toml
      # If using Docker's default `bridge` network setting the dns listening mode should be set to 'all'
      - FTLCONF_dns_listeningMode=ALL
      #https://docs.pi-hole.net/docker/configuration/?h=ftlconf_dns_dnssec#configuring-ftl-via-the-environment
      - FTLCONF_dns_upstreams=9.9.9.9;149.112.112.112
      # https://docs.pi-hole.net/docker/upgrading/v5-v6/?h=dhcp_active#dhcp-variables
      - FTLCONF_dhcp_active=true
      - FTLCONF_dhcp_start=192.168.50.100
      - FTLCONF_dhcp_end=192.168.50.200
      - FTLCONF_dhcp_router=192.168.50.1
      - FTLCONF_dhcp_leaseTime=24h
      # route all subdomains to ip address, pay attention to key word server and not address
      - FTLCONF_misc_dnsmasq_lines=server=/miloszivanovic.me/10.25.25.4
    volumes:
      - .pihole/config/etc-dnsmasq.d:/etc/dnsmasq.d
    cap_add:
      - NET_ADMIN
    restart: unless-stopped
    network_mode: "host"
EOF

sudo reboot

mkdir -p .wireguard/conf

# ===========================
# This is example file for WireGuard configuration
# Copy real client data to ~/.wireguard/config/wg0.conf
# tee .wireguard/config/wg0.conf > /dev/null <<EOF 
# [Interface]
# Address =
# PrivateKey =
# ListenPort =
# DNS =

# [Peer]
# PublicKey =
# PresharedKey = 
# Endpoint =
# AllowedIPs =
# EOF
# ===========================

sudo nmcli device wifi rescan ifname wlan0
# nmcli device wifi list ifname wlan0
nmcli device wifi list
sudo nmcli dev wifi connect "AndroidAP" password "1234567890" ifname wlan0
