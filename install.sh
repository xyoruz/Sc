#!/bin/bash
# ============================================================
# Wongreang-Sc - VPN Tunneling Installer
# Support: SSH, VMess, VLESS, Trojan, Shadowsocks, OpenVPN
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# KONFIGURASI UTAMA (SESUAI PORT MAP)
# ============================================================
DOMAIN=""
OS_INFO=""
ARCH=$(uname -m)
TIMEZONE="Asia/Jakarta"

# Port Configuration
SSH_PORT=22
UDP_SSH_RANGE="1:65535"
SLOWDNS_PORTS="53,80,443"
DROPBEAR_PORTS="109,143,443"
DROPBEAR_WS_PORT=109
SSH_WS_SSL_PORT=443
SSH_WS_PORT=80
SSH_SSL_PORT=443
OPENVPN_TCP_PORT1=443
OPENVPN_TCP_PORT2=1194
OPENVPN_UDP_PORT=2200
NGINX_PORTS="80,81,443"
HAPROXY_PORTS="80,443"
XRAY_TLS_PORT=443
XRAY_NTLS_PORTS="80,2086,8080,8880"
TROJAN_PORT=443
SS_PORT=443
ANYTLS_PORT=8443
ANYNTLS_PORTS="2086,8080,8880"
BADVPN_PORTS="7100,7200,7300"

# ============================================================
# CEK ROOT
# ============================================================
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[ERROR]${NC} Script harus dijalankan sebagai root!"
   exit 1
fi

# ============================================================
# DETEKSI OS
# ============================================================
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
        OS_INFO="$OS_NAME $OS_VERSION"
    else
        echo -e "${RED}[ERROR]${NC} OS tidak didukung!"
        exit 1
    fi
    
    case $OS_NAME in
        ubuntu)
            if [[ $OS_VERSION =~ ^(18.04|20.04|22.04|24.04)$ ]]; then
                echo -e "${GREEN}[OK]${NC} Ubuntu $OS_VERSION terdeteksi"
            else
                echo -e "${YELLOW}[WARN]${NC} Ubuntu $OS_VERSION mungkin tidak fully supported"
            fi
            ;;
        debian)
            if [[ $OS_VERSION =~ ^(9|10|11|12)$ ]]; then
                echo -e "${GREEN}[OK]${NC} Debian $OS_VERSION terdeteksi"
            else
                echo -e "${YELLOW}[WARN]${NC} Debian $OS_VERSION mungkin tidak fully supported"
            fi
            ;;
        *)
            echo -e "${RED}[ERROR]${NC} OS $OS_NAME tidak didukung!"
            exit 1
            ;;
    esac
}

# ============================================================
# BANNER
# ============================================================
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    ╔══════════════════════════════════════════════════════════╗
    ║                                                          ║
    ║            W O N G R E A N G - S C                       ║
    ║                                                          ║
    ║   Advanced VPN Tunneling Installation & Management       ║
    ║   SSH • VMess • VLESS • Trojan • Shadowsocks             ║
    ║                                                          ║
    ╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# ============================================================
# SETUP TIMEZONE
# ============================================================
setup_timezone() {
    echo -e "${BLUE}[INFO]${NC} Setting timezone ke $TIMEZONE..."
    timedatectl set-timezone $TIMEZONE 2>/dev/null || ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
    echo -e "${GREEN}[OK]${NC} Timezone: $(date)"
}

# ============================================================
# UPDATE & INSTALL DEPENDENCIES
# ============================================================
install_dependencies() {
    echo -e "${BLUE}[INFO]${NC} Update repository & install dependencies..."
    apt update -y && apt upgrade -y
    
    apt install -y \
        curl wget git unzip zip sudo \
        apt-transport-https software-properties-common \
        ca-certificates gnupg lsb-release \
        net-tools htop vnstat screen tmux \
        iptables iptables-persistent \
        socat cron logrotate \
        nginx haproxy \
        openssl jq bc \
        python3 python3-pip \
        build-essential cmake \
        uuid-runtime \
        fail2ban \
        dos2unix \
        speedtest-cli
    
    echo -e "${GREEN}[OK]${NC} Dependencies terinstall"
}

# ============================================================
# SETUP SSH
# ============================================================
setup_ssh() {
    echo -e "${BLUE}[INFO]${NC} Konfigurasi SSH..."
    
    # Backup config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Konfigurasi SSH
    cat > /etc/ssh/sshd_config << 'EOF'
Port 22
AddressFamily any
ListenAddress 0.0.0.0
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin yes
MaxAuthTries 3
MaxSessions 100
PubkeyAuthentication yes
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding yes
PrintMotd no
ClientAliveInterval 120
ClientAliveCountMax 3
UseDNS no
Banner /etc/issue.net
EOF

    # Buat banner
    cat > /etc/issue.net << 'EOF'
╔══════════════════════════════════════════════════════════╗
║              W O N G R E A N G - S C                     ║
║         Premium VPN Tunneling Service                    ║
╚══════════════════════════════════════════════════════════╝
EOF

    systemctl restart ssh
    echo -e "${GREEN}[OK]${NC} SSH dikonfigurasi pada port 22"
}

# ============================================================
# INSTALL DROPBEAR
# ============================================================
install_dropbear() {
    echo -e "${BLUE}[INFO]${NC} Install Dropbear SSH..."
    
    apt install -y dropbear
    
    # Konfigurasi Dropbear multi-port
    cat > /etc/default/dropbear << 'EOF'
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143 -p 443 -W 65535"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
EOF

    systemctl enable dropbear
    systemctl restart dropbear
    echo -e "${GREEN}[OK]${NC} Dropbear aktif pada port 109, 143, 443"
}

# ============================================================
# INSTALL STUNNEL (SSL/TLS TUNNEL)
# ============================================================
install_stunnel() {
    echo -e "${BLUE}[INFO]${NC} Install Stunnel untuk SSL/TLS tunnel..."
    
    apt install -y stunnel4
    
    # Generate certificate
    mkdir -p /etc/stunnel
    openssl req -new -x509 -days 3650 -nodes \
        -out /etc/stunnel/stunnel.pem \
        -keyout /etc/stunnel/stunnel.pem \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Wongreang/CN=wongreang.local" \
        2>/dev/null
    
    chmod 600 /etc/stunnel/stunnel.pem
    
    # Konfigurasi Stunnel
    cat > /etc/stunnel/stunnel.conf << 'EOF'
pid = /var/run/stunnel4.pid
cert = /etc/stunnel/stunnel.pem
client = no
socket = a:SO_REUSEADDR=1
socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
TIMEOUTclose = 0

[ssh-ssl]
accept = 443
connect = 127.0.0.1:22

[dropbear-ssl]
accept = 444
connect = 127.0.0.1:109
EOF

    # Enable stunnel
    sed -i 's/ENABLED=0/ENABLED=1/' /etc/default/stunnel4
    systemctl enable stunnel4
    systemctl restart stunnel4
    echo -e "${GREEN}[OK]${NC} Stunnel aktif pada port 443 (SSH SSL)"
}

# ============================================================
# INSTALL XRAY (VMess, VLESS, Trojan, Shadowsocks)
# ============================================================
install_xray() {
    echo -e "${BLUE}[INFO]${NC} Install Xray Core..."
    
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    # Generate UUID & Password
    UUID=$(cat /proc/sys/kernel/random/uuid)
    TROJAN_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    SS_PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
    
    # Generate SSL Certificates untuk Xray
    mkdir -p /etc/xray/cert
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/xray/cert/private.key \
        -out /etc/xray/cert/public.crt \
        -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Wongreang/CN=wongreang.local" \
        2>/dev/null
    
    # Konfigurasi Xray
    cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "tag": "vless-tls",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-direct",
            "level": 0,
            "email": "vless@wongreang"
          }
        ],
        "decryption": "none",
        "fallbacks": [
          {
            "dest": 80
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "alpn": ["http/1.1"],
          "certificates": [
            {
              "certificateFile": "/etc/xray/cert/public.crt",
              "keyFile": "/etc/xray/cert/private.key"
            }
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "port": 80,
      "protocol": "vmess",
      "tag": "vmess-ntls",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0,
            "email": "vmess@wongreang"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "port": 2086,
      "protocol": "vless",
      "tag": "vless-ntls",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "email": "vless-ntls@wongreang"
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
    },
    {
      "port": 8080,
      "protocol": "vmess",
      "tag": "vmess-ws",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "alterId": 0,
            "email": "vmess-ws@wongreang"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess-ws"
        }
      }
    },
    {
      "port": 8880,
      "protocol": "vless",
      "tag": "vless-ws",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "email": "vless-ws@wongreang"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless-ws"
        }
      }
    },
    {
      "port": 8443,
      "protocol": "trojan",
      "tag": "trojan-tls",
      "settings": {
        "clients": [
          {
            "password": "$TROJAN_PASS",
            "email": "trojan@wongreang"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/cert/public.crt",
              "keyFile": "/etc/xray/cert/private.key"
            }
          ]
        }
      }
    },
    {
      "port": 8388,
      "protocol": "shadowsocks",
      "tag": "shadowsocks",
      "settings": {
        "method": "aes-256-gcm",
        "password": "$SS_PASS",
        "network": "tcp,udp"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      }
    ]
  }
}
EOF

    # Simpan kredensial
    mkdir -p /etc/wongreang
    cat > /etc/wongreang/credentials.txt << EOF
========================================
WONGREANG-SC CREDENTIALS
========================================
UUID          : $UUID
Trojan Pass   : $TROJAN_PASS
SS Password   : $SS_PASS
========================================
EOF
    
    chmod 600 /etc/wongreang/credentials.txt
    
    systemctl enable xray
    systemctl restart xray
    echo -e "${GREEN}[OK]${NC} Xray aktif (VMess/VLESS/Trojan/SS)"
}

# ============================================================
# INSTALL WEBSOCKET PROXY (untuk SSH WS)
# ============================================================
install_ws_proxy() {
    echo -e "${BLUE}[INFO]${NC} Install WebSocket proxy untuk SSH..."
    
    # Install Python websocket
    pip3 install websockets
    
    # Buat script WS proxy
    cat > /usr/local/bin/ws-ssh << 'EOF'
#!/usr/bin/env python3
import asyncio
import websockets

async def ssh_handler(websocket, path=None):
    try:
        reader, writer = await asyncio.open_connection('127.0.0.1', 22)
        
        async def forward_ws_to_ssh():
            try:
                async for message in websocket:
                    writer.write(message)
                    await writer.drain()
            except:
                pass
        
        async def forward_ssh_to_ws():
            try:
                while True:
                    data = await reader.read(4096)
                    if not data:
                        break
                    await websocket.send(data)
            except:
                pass
        
        await asyncio.gather(forward_ws_to_ssh(), forward_ssh_to_ws())
    except Exception:
        pass
    finally:
        try:
            writer.close()
        except:
            pass

async def main():
    async with websockets.serve(ssh_handler, "0.0.0.0", 109, ping_interval=None):
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
EOF

    chmod +x /usr/local/bin/ws-ssh
    
    # Buat systemd service
    cat > /etc/systemd/system/ws-ssh.service << 'EOF'
[Unit]
Description=WebSocket SSH Proxy - Wongreang-Sc
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/ws-ssh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable ws-ssh
    systemctl restart ws-ssh
    echo -e "${GREEN}[OK]${NC} WS SSH aktif pada port 109"
}

# ============================================================
# INSTALL OPENVPN
# ============================================================
install_openvpn() {
    echo -e "${BLUE}[INFO]${NC} Install OpenVPN..."
    
    apt install -y openvpn easy-rsa
    
    mkdir -p /etc/openvpn/easy-rsa
    cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
    
    cd /etc/openvpn/easy-rsa
    
    # Setup vars
    cat > vars << 'EOF'
set_var EASYRSA_ALGO "ec"
set_var EASYRSA_DIGEST "sha512"
set_var EASYRSA_REQ_COUNTRY "ID"
set_var EASYRSA_REQ_PROVINCE "Jakarta"
set_var EASYRSA_REQ_CITY "Jakarta"
set_var EASYRSA_REQ_ORG "Wongreang"
set_var EASYRSA_REQ_EMAIL "admin@wongreang.local"
set_var EASYRSA_REQ_OU "VPN"
EOF
    
    ./easyrsa init-pki
    ./easyrsa --batch build-ca nopass
    ./easyrsa --batch gen-req server nopass
    ./easyrsa --batch sign-req server server
    ./easyrsa gen-dh
    
    openvpn --genkey --secret ta.key
    
    # Copy files
    cp pki/ca.crt /etc/openvpn/
    cp pki/issued/server.crt /etc/openvpn/
    cp pki/private/server.key /etc/openvpn/
    cp pki/dh.pem /etc/openvpn/
    cp ta.key /etc/openvpn/
    
    # Konfigurasi OpenVPN TCP 1194
    cat > /etc/openvpn/server-tcp.conf << 'EOF'
port 1194
proto tcp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
tls-auth /etc/openvpn/ta.key 0
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status-tcp.log
verb 3
EOF

    # Konfigurasi OpenVPN UDP 2200
    cat > /etc/openvpn/server-udp.conf << 'EOF'
port 2200
proto udp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
tls-auth /etc/openvpn/ta.key 0
server 10.9.0.0 255.255.255.0
ifconfig-pool-persist ipp-udp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
cipher AES-256-CBC
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status-udp.log
verb 3
EOF

    # Enable IP forwarding
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p
    
    # Enable service
    systemctl enable openvpn@server-tcp
    systemctl enable openvpn@server-udp
    systemctl start openvpn@server-tcp
    systemctl start openvpn@server-udp
    
    echo -e "${GREEN}[OK]${NC} OpenVPN aktif (TCP 1194, UDP 2200)"
}

# ============================================================
# INSTALL BADVPN (UDPGW)
# ============================================================
install_badvpn() {
    echo -e "${BLUE}[INFO]${NC} Install BadVPN UDPGW..."
    
    apt install -y cmake build-essential
    
    cd /usr/local
    git clone https://github.com/ambrop72/badvpn.git 2>/dev/null
    
    cd badvpn
    mkdir -p build && cd build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 > /dev/null 2>&1
    make > /dev/null 2>&1
    cp udpgw/badvpn-udpgw /usr/local/bin/
    
    # Buat service
    cat > /etc/systemd/system/badvpn.service << 'EOF'
[Unit]
Description=BadVPN UDPGW - Wongreang-Sc
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7100 --max-clients 1000 --max-connections-for-client 10
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable badvpn
    systemctl restart badvpn
    echo -e "${GREEN}[OK]${NC} BadVPN UDPGW aktif pada port 7100"
}

# ============================================================
# SETUP FIREWALL (IPTABLES)
# ============================================================
setup_firewall() {
    echo -e "${BLUE}[INFO]${NC} Setup firewall rules..."
    
    # Flush existing
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    
    # Default policy
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    
    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT
    
    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    
    # Allow SSH
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    
    # Allow Dropbear
    for port in 109 143 443; do
        iptables -A INPUT -p tcp --dport $port -j ACCEPT
    done
    
    # Allow Xray ports
    for port in 80 443 2086 8080 8880 8443 8388; do
        iptables -A INPUT -p tcp --dport $port -j ACCEPT
    done
    
    # Allow OpenVPN
    iptables -A INPUT -p tcp --dport 1194 -j ACCEPT
    iptables -A INPUT -p udp --dport 2200 -j ACCEPT
    
    # Allow BadVPN
    for port in 7100 7200 7300; do
        iptables -A INPUT -p tcp --dport $port -j ACCEPT
        iptables -A INPUT -p udp --dport $port -j ACCEPT
    done
    
    # Allow UDP SSH range
    iptables -A INPUT -p udp --dport 1:65535 -j ACCEPT
    
    # NAT for OpenVPN
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
    iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o eth0 -j MASQUERADE
    
    # Save rules
    netfilter-persistent save
    
    echo -e "${GREEN}[OK]${NC} Firewall rules dikonfigurasi"
}

# ============================================================
# SETUP NGINX
# ============================================================
setup_nginx() {
    echo -e "${
