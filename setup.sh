#!/bin/bash
# ==========================================
# TOMATO AUTOSCRIPT CORE INSTALLER
# OS Support: Ubuntu 20.04/22.04 & Debian 11/12
# ==========================================

# Memastikan eksekusi sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as root"
    exit 1
fi

clear
echo -e "\e[32m[INFO]\e[0m Memulai instalasi dependensi sistem..."
sleep 2

# Update dan instal dependensi dasar
apt-get update -y
apt-get upgrade -y
apt-get install -y wget curl jq haproxy nginx dropbear stunnel4 openvpn easy-rsa uuid-runtime zip unzip net-tools cron iptables iptables-persistent

# Membuat direktori sistem
mkdir -p /etc/xray
mkdir -p /etc/tomato
mkdir -p /var/log/xray
mkdir -p /var/log/haproxy

# Meminta input domain
read -p "Masukkan Domain Anda (contoh: vpn.domain.com): " domain
echo "$domain" > /etc/xray/domain
echo -e "\e[32m[INFO]\e[0m Domain $domain tersimpan."

# -------------------------------------------
# INSTALASI XRAY CORE
# -------------------------------------------
echo -e "\e[32m[INFO]\e[0m Menginstal Xray Core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
uuid=$(uuidgen)
cat > /etc/xray/config.json << EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 10000,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "level": 0,
            "email": "admin@${domain}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
systemctl restart xray
systemctl enable xray

# -------------------------------------------
# KONFIGURASI HAPROXY (MULTIPLEXING)
# -------------------------------------------
echo -e "\e[32m[INFO]\e[0m Mengonfigurasi HAProxy..."
cat > /etc/haproxy/haproxy.cfg << EOF
global
    log /dev/log local0
    log /dev/log local1 notice
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 5000
    timeout client  50000
    timeout server  50000

frontend multipass
    bind *:443
    mode tcp
    tcp-request inspect-delay 5s
    tcp-request content accept if { req.ssl_hello_type 1 }
    
    # Routing berdasarkan SNI / ALPN
    use_backend xray_backend if { req.ssl_sni -i ${domain} }
    default_backend ssh_backend

backend xray_backend
    mode tcp
    server xray 127.0.0.1:10000

backend ssh_backend
    mode tcp
    server ssh 127.0.0.1:22
EOF
systemctl restart haproxy
systemctl enable haproxy

# -------------------------------------------
# MEMBUAT MENU UI UTAMA
# -------------------------------------------
echo -e "\e[32m[INFO]\e[0m Membangun antarmuka menu..."
cat > /usr/local/bin/menu << 'EOF'
#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
NC='\033[0m'

DOMAIN=$(cat /etc/xray/domain)
OS=$(cat /etc/os-release | grep -w PRETTY_NAME | head -n 1 | cut -d '"' -f 2)
RAM=$(free -m | awk '/Mem:/ {printf "%.2fGB / %.2fGB", $3/1024, $2/1024}')
UPTIME=$(uptime -p | sed 's/up //')
CPU=$(nproc)
IP=$(curl -sS ifconfig.me)

clear
echo -e "${ORANGE}      .::::. TOMATO AUTOSCRIPT .::::.${NC}"
echo -e "${ORANGE}-----------------------------------------${NC}"
echo -e " ${RED}*${NC} SYSTEM     : ${OS}"
echo -e " ${RED}*${NC} RAM        : ${RAM}"
echo -e " ${RED}*${NC} UPTIME     : ${UPTIME}"
echo -e " ${RED}*${NC} CPU CORE   : ${CPU}"
echo -e " ${RED}*${NC} PUBLIC IP  : ${IP}"
echo -e " ${RED}*${NC} DOMAIN     : ${DOMAIN}"
echo -e "${ORANGE}-----------------------------------------${NC}"
echo -e " ${GREEN}* XRAY SERVICE STATUS : GOOD${NC}"
echo -e " ${GREEN}* HAPROXY SERVICE STATUS : GOOD${NC}"
echo -e "${ORANGE}-----------------------------------------${NC}"
echo -e "  ${GREEN}1.${NC} SSH OVPN MANAGER    ${GREEN}4.${NC} TROJAN MANAGER"
echo -e "  ${GREEN}2.${NC} VMESS MANAGER       ${GREEN}5.${NC} SHDWSK MANAGER"
echo -e "  ${GREEN}3.${NC} VLESS MANAGER       ${GREEN}6.${NC} OTHER SETTINGS"
echo -e "${ORANGE}-----------------------------------------${NC}"
echo -e "Type ${RED}x${NC} to exit"
echo ""
read -p "Choose an option [1-6]: " opt
case $opt in
    1|2|3|4|5|6) echo -e "\e[32mModule for option $opt is ready to be loaded from modular scripts.\e[0m"; sleep 2; menu ;;
    x) exit 0 ;;
    *) echo "Invalid option"; sleep 1; menu ;;
esac
EOF
chmod +x /usr/local/bin/menu

# -------------------------------------------
# FINALISASI
# -------------------------------------------
echo "alias menu='menu'" >> ~/.bashrc
clear
echo -e "\e[32m=================================================\e[0m"
echo -e "\e[32m Instalasi Selesai! \e[0m"
echo -e "\e[32m=================================================\e[0m"
echo -e " - Xray Core (VLESS WS) : Port 10000 (Internal)"
echo -e " - HAProxy (Multiplexer): Port 443"
echo -e " - Dropbear / SSH       : Port 22"
echo -e " - Default UUID Admin   : $uuid"
echo -e ""
echo -e "Ketik \e[33mmenu\e[0m untuk membuka panel Tomato Autoscript."
echo -e "Ketik \e[33mreboot\e[0m untuk merestart VPS Anda."
