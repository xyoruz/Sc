#!/bin/bash
# ============================================================
# prem.sh - Installer utama autoscript XyrVPN
# Gaya: Tomketstore (flatten ke /usr/local/sbin)
# Jalankan: wget -q <url>/prem.sh && chmod +x prem.sh && ./prem.sh
# ============================================================

# ---------- Identitas Repo ----------
REPO_USER="xyoruz"
REPO_NAME="Sc"
REPO_BRANCH="main"
REPO="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}"

# ---------- Pastikan root ----------
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "[ERROR] Jalankan sebagai root!"
    exit 1
fi

# ---------- Warna ----------
C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'
C_PURPLE='\033[1;35m'
OK="${C_GREEN}--->${C_RESET}"
ERR="${C_RED}[ERROR]${C_RESET}"

# ---------- Helper ----------
print_step() {
    echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
    echo -e "${C_YELLOW} $1 ${C_RESET}"
    echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
    sleep 1
}
print_ok()   { echo -e "${OK} $1"; }
print_err()  { echo -e "${ERR} $1"; }

# ---------- Clear & Banner ----------
clear
echo -e "${C_YELLOW}----------------------------------------------------------${C_RESET}"
echo -e "     WELCOME TO ${C_GREEN}XYR TUNNELING SCRIPT${C_RESET} (Stable)"
echo -e "     PROSES PENGECEKAN SISTEM ANDA !!"
echo -e "${C_PURPLE}----------------------------------------------------------${C_RESET}"
echo -e " › AUTHOR : Xyr Store"
echo -e " › VERSION: 1.0.0"
echo -e "${C_YELLOW}----------------------------------------------------------${C_RESET}"
sleep 2

# ---------- Cek Arsitektur ----------
if [[ "$(uname -m)" != "x86_64" ]]; then
    print_err "Arsitektur $(uname -m) tidak didukung (harus x86_64)"
    exit 1
else
    print_ok "Arsitektur didukung: $(uname -m)"
fi

# ---------- Cek OS ----------
if [[ -f /etc/os-release ]]; then
    # shellcheck source=/dev/null
    source /etc/os-release
    OS_ID="$ID"
    OS_VER="$VERSION_ID"
else
    print_err "/etc/os-release tidak ditemukan"
    exit 1
fi

SUPPORTED=0
case "$OS_ID" in
    ubuntu)
        case "$OS_VER" in
            20.04|22.04|24.04) SUPPORTED=1 ;;
        esac
        ;;
    debian)
        case "$OS_VER" in
            10|11|12) SUPPORTED=1 ;;
        esac
        ;;
esac

if [[ $SUPPORTED -eq 1 ]]; then
    print_ok "OS didukung: $PRETTY_NAME"
else
    print_err "OS tidak didukung: $PRETTY_NAME"
    print_err "Didukung: Ubuntu 20/22/24, Debian 10/11/12"
    exit 1
fi

# ---------- Cek OpenVZ ----------
VIRT=$(systemd-detect-virt 2>/dev/null || echo "unknown")
if [[ "$VIRT" == "openvz" ]]; then
    print_err "OpenVZ tidak didukung"
    exit 1
fi
print_ok "Virtualisasi: $VIRT"

# ---------- Cek IP ----------
IP=$(curl -sS --max-time 10 https://ipv4.icanhazip.com 2>/dev/null)
if [[ -z "$IP" ]]; then
    print_err "Tidak dapat mendeteksi IP publik"
    exit 1
fi
print_ok "IP Publik: $IP"

echo ""
read -rp "Tekan [Enter] untuk mulai instalasi..."
clear

# ============================================================
# FUNGSI INSTALLASI
# ============================================================

# ---------- Update & Install Paket Dasar ----------
first_setup() {
    print_step "Update & Install Paket Dasar"
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -y
    apt-get install -y --no-install-recommends \
        curl wget sudo unzip zip tar gzip bzip2 \
        nano vim htop screen tmux net-tools \
        jq bc socat lsof psmisc ca-certificates \
        gnupg lsb-release apt-transport-https \
        cron rsyslog logrotate fail2ban \
        iptables iptables-persistent netfilter-persistent \
        openssl uuid-runtime \
        cmake g++ make git

    systemctl enable --now cron 2>/dev/null
    systemctl enable --now rsyslog 2>/dev/null
    systemctl enable --now fail2ban 2>/dev/null
    systemctl enable --now netfilter-persistent 2>/dev/null

    print_ok "Paket dasar terinstall"
}

# ---------- Install SSH & Dropbear ----------
install_ssh() {
    print_step "Install SSH & Dropbear"
    apt-get install -y openssh-server dropbear

    if [[ -f /etc/default/dropbear ]]; then
        sed -i 's/^NO_START=.*/NO_START=0/' /etc/default/dropbear
        sed -i 's/^DROPBEAR_PORT=.*/DROPBEAR_PORT=143/' /etc/default/dropbear
        sed -i 's/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 109 -p 143"/' /etc/default/dropbear
    fi

    systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null
    systemctl enable --now dropbear 2>/dev/null

    print_ok "SSH & Dropbear aktif"
}

# ---------- Install Nginx ----------
install_nginx() {
    print_step "Install Nginx"
    apt-get install -y nginx

    mkdir -p /var/www/html
    systemctl enable --now nginx
    print_ok "Nginx aktif"
}

# ---------- Install HAProxy ----------
install_haproxy() {
    print_step "Install HAProxy"
    apt-get install -y haproxy
    systemctl enable haproxy
    print_ok "HAProxy terinstall"
}

# ---------- Install Xray ----------
install_xray() {
    print_step "Install Xray Core"

    if command -v xray >/dev/null 2>&1; then
        print_ok "Xray sudah terinstall, skip"
        return 0
    fi

    bash -c "$(curl -sSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

    mkdir -p /etc/xray /var/log/xray
    touch /var/log/xray/access.log /var/log/xray/error.log
    chmod -R 755 /var/log/xray

    systemctl enable xray
    print_ok "Xray terinstall"
}

# ---------- Install Tools Tambahan ----------
install_tools() {
    print_step "Install Tools Tambahan"

    apt-get install -y vnstat >/dev/null 2>&1
    systemctl enable --now vnstat 2>/dev/null

    apt-get install -y speedtest-cli 2>/dev/null || true
    apt-get install -y rclone 2>/dev/null || true
    apt-get install -y at 2>/dev/null || true
    systemctl enable --now atd 2>/dev/null || true

    if [[ ! -d /root/.acme.sh ]]; then
        curl -sSL https://get.acme.sh | sh -s email=admin@example.com >/dev/null 2>&1 || true
    fi

    print_ok "Tools tambahan terinstall"
}

# ---------- Install UDP Services (Opsional) ----------
install_udp_services() {
    print_step "Install UDP Services (Opsional)"

    if [[ "$VIRT" == "openvz" ]]; then
        print_err "OpenVZ terdeteksi. Skip UDP."
        return 0
    fi

    if [[ ! -e /dev/net/tun ]]; then
        mkdir -p /dev/net
        mknod /dev/net/tun c 10 200 2>/dev/null
        chmod 666 /dev/net/tun
    fi

    if [[ -e /dev/net/tun ]]; then
        print_ok "TUN device tersedia"
    else
        print_err "TUN tidak tersedia. UDP tidak akan jalan."
    fi

    print_ok "UDP installer siap"
    print_err "Install UDP Custom via menu → [7] Utility → [12] Install UDP"
}

# ---------- Buat Struktur Folder ----------
make_folders() {
    print_step "Buat Struktur Folder"

    mkdir -p /usr/local/sbin/xyr/lib
    mkdir -p /etc/xyr/db
    mkdir -p /etc/xyr/quota/{vmess,vless,trojan,ss,ssh}
    mkdir -p /etc/xyr/limit/{vmess,vless,trojan,ss,ssh}
    mkdir -p /etc/xyr/usage/{vmess,vless,trojan,ss,ssh}
    mkdir -p /etc/xyr/locked/{vmess,vless,trojan,ss,ssh}
    mkdir -p /var/log/xyr /var/backups/xyr /var/www/html

    touch /etc/xyr/db/vmess.db
    touch /etc/xyr/db/vless.db
    touch /etc/xyr/db/trojan.db
    touch /etc/xyr/db/shadowsocks.db
    touch /etc/xyr/db/ssh.db

    echo "OFF" > /etc/xyr/autolock

    print_ok "Folder & file data siap"
}

# ---------- Helper: Download dengan Retry ----------
safe_dl() {
    local url="$1" out="$2"
    local try=0
    while [[ $try -lt 3 ]]; do
        if curl -fsSL --max-time 15 "$url" -o "$out" 2>/dev/null; then
            return 0
        fi
        try=$((try + 1))
        sleep 1
    done
    return 1
}

# ---------- Download Library ----------
download_lib() {
    print_step "Download Library (config, common, validate, xray-helper)"

    local base="/usr/local/sbin/xyr/lib"
    local files=("config.sh" "common.sh" "validate.sh" "xray-helper.sh")

    for f in "${files[@]}"; do
        if safe_dl "${REPO}/lib/${f}" "${base}/${f}"; then
            chmod 644 "${base}/${f}"
            print_ok "Downloaded: $f"
        else
            print_err "Gagal download: $f"
            exit 1
        fi
    done
}

# ---------- Download Menu & Script ----------
download_menu() {
    print_step "Download Menu & Scripts"

    local files_menu=(
        "menu/menu"
        "menu/m-ssh" "menu/m-vmess" "menu/m-vless" "menu/m-trojan" "menu/m-ss"
        "menu/m-trial" "menu/m-utility" "menu/m-limit" "menu/m-bot"
        "menu/menu-backup" "menu/menu-x"
    )

    local files_ssh=(
        "ssh/addssh" "ssh/delssh" "ssh/renewssh" "ssh/cekssh"
        "ssh/member" "ssh/trial" "ssh/lock" "ssh/unlock"
        "ssh/autokill" "ssh/ceklim" "ssh/delexp"
        "ssh/delssh-auto" "ssh/tendang"
    )

    local files_vmess=(
        "vmess/addws" "vmess/delws" "vmess/renewws" "vmess/cekws"
        "vmess/trialws" "vmess/member-ws"
    )

    local files_vless=(
        "vless/addvless" "vless/delvless" "vless/renewvless" "vless/cekvless"
        "vless/trialvless"
    )

    local files_trojan=(
        "trojan/addtr" "trojan/deltr" "trojan/renewtr" "trojan/cektr"
        "trojan/trialtr"
    )

    local files_ss=(
        "ss/addss" "ss/delss" "ss/renewss" "ss/cekss" "ss/trialss"
    )

    local files_limit=(
        "limit/limit-ip" "limit/limit-quota"
        "limit/lock-user" "limit/unlock-user" "limit/cek-lock"
        "limit/limitip-cron" "limit/limitquota-cron"
    )

    local files_utility=(
        "utility/xp" "utility/healthcheck"
        "utility/addhost" "utility/clearlog" "utility/clearcache"
        "utility/autoreboot" "utility/autokill"
        "utility/prot" "utility/bw" "utility/info" "utility/speedtest"
        "utility/del-auto"
        "utility/init-config"
        "utility/verify"
        "utility/install-udp"
        "utility/install-udp-custom"
        "utility/uninstall-udp"
    )

    local all_files=(
        "${files_menu[@]}"
        "${files_ssh[@]}"
        "${files_vmess[@]}"
        "${files_vless[@]}"
        "${files_trojan[@]}"
        "${files_ss[@]}"
        "${files_limit[@]}"
        "${files_utility[@]}"
    )

    local total=${#all_files[@]}
    local i=0
    for path in "${all_files[@]}"; do
        i=$((i + 1))
        local name
        name=$(basename "$path")
        printf "[%2d/%d] %-25s " "$i" "$total" "$name"
        if safe_dl "${REPO}/${path}" "/usr/local/sbin/${name}"; then
            chmod +x "/usr/local/sbin/${name}"
            echo -e "${C_GREEN}OK${C_RESET}"
        else
            echo -e "${C_YELLOW}SKIP${C_RESET}"
        fi
    done

    print_ok "Download selesai"
}

# ---------- Download Config Pendukung ----------
download_config() {
    print_step "Download Config Pendukung"

    if safe_dl "${REPO}/config/nginx.conf" /etc/nginx/nginx.conf; then
        print_ok "nginx.conf terpasang"
    fi

    if safe_dl "${REPO}/config/xray-config.json" /etc/xray/config.json; then
        print_ok "xray-config.json terpasang"
    fi

    if safe_dl "${REPO}/config/dropbear" /etc/default/dropbear; then
        print_ok "dropbear terpasang"
    fi

    if safe_dl "${REPO}/config/haproxy.cfg" /etc/haproxy/haproxy.cfg; then
        print_ok "haproxy.cfg terpasang"
    fi

    mkdir -p /etc/systemd/system/xray.service.d
    if safe_dl "${REPO}/config/systemd-xray-override.conf" /etc/systemd/system/xray.service.d/override.conf; then
        systemctl daemon-reload
        print_ok "systemd override terpasang"
    fi

    if safe_dl "${REPO}/config/sshd_config" /tmp/sshd_config.new; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak 2>/dev/null
        cp /tmp/sshd_config.new /etc/ssh/sshd_config
        if ! sshd -t 2>/dev/null; then
            cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
            print_err "sshd_config gagal, rollback"
        else
            print_ok "sshd_config terpasang"
        fi
        rm -f /tmp/sshd_config.new
    fi
}

# ---------- Inisialisasi Config Xray ----------
init_xray_config() {
    print_step "Inisialisasi Config Xray"

    if [[ -x /usr/local/sbin/init-config ]]; then
        bash /usr/local/sbin/init-config < /dev/null
    else
        print_err "init-config tidak ada, skip"
    fi
}

# ---------- Setting Timezone ----------
set_timezone() {
    print_step "Setting Timezone"
    ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
    echo "Asia/Jakarta" > /etc/timezone
    systemctl restart cron 2>/dev/null
    print_ok "Timezone: Asia/Jakarta"
}

# ---------- Setup Cron ----------
setup_cron() {
    print_step "Setup Cron Auto"

    rm -f /etc/cron.d/xyr-*

    cat > /etc/cron.d/xyr-limitip <<-END
* * * * * root /usr/local/sbin/limitip-cron >/dev/null 2>&1
END

    cat > /etc/cron.d/xyr-limitquota <<-END
*/5 * * * * root /usr/local/sbin/limitquota-cron >/dev/null 2>&1
END

    cat > /etc/cron.d/xyr-xp <<-END
0 * * * * root /usr/local/sbin/xp >/dev/null 2>&1
END

    cat > /etc/cron.d/xyr-health <<-END
*/10 * * * * root /usr/local/sbin/healthcheck >/dev/null 2>&1
END

    chmod 644 /etc/cron.d/xyr-*
    systemctl restart cron 2>/dev/null

    print_ok "Cron terpasang"
}

# ---------- Systemd Override ----------
systemd_tuning() {
    print_step "Systemd Tuning (Restart=always, LimitNOFILE)"

    local services=("xray" "nginx" "haproxy" "dropbear" "ssh" "sshd" "badvpn-udpgw" "badvpn-udpgw2" "badvpn-udpgw3" "udp-custom")

    for svc in "${services[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}.service"; then
            mkdir -p "/etc/systemd/system/${svc}.service.d"
            cat > "/etc/systemd/system/${svc}.service.d/override.conf" <<-END
[Service]
Restart=always
RestartSec=3
LimitNOFILE=1048576
END
        fi
    done

    systemctl daemon-reload
    print_ok "Systemd override terpasang"
}

# ---------- Log Rotation ----------
setup_logrotate() {
    print_step "Setup Log Rotation"
    cat > /etc/logrotate.d/xyr <<-END
/var/log/xyr/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0644 root root
}

/var/log/xray/*.log {
    daily
    rotate 7
    compress
    missingok
    notifempty
    create 0644 root root
}
END
    print_ok "Log rotation aktif"
}

# ---------- Enable Service ----------
enable_services() {
    print_step "Enable & Start Service"

    for svc in nginx xray dropbear ssh cron fail2ban vnstat; do
        systemctl enable "$svc" 2>/dev/null || true
        systemctl restart "$svc" 2>/dev/null || true
    done

    print_ok "Semua service aktif"
}

# ---------- Set Hostname ----------
set_hostname() {
    print_step "Set Hostname"
    local hn="${IP//./-}"
    hostnamectl set-hostname "xyr-${hn}" 2>/dev/null || true
    print_ok "Hostname: xyr-${hn}"
}

# ---------- Info Akhir ----------
final_info() {
    print_step "Instalasi Selesai"
    echo ""
    echo -e "${C_GREEN}╔════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_GREEN}║         INSTALASI BERHASIL                 ║${C_RESET}"
    echo -e "${C_GREEN}╚════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e " IP VPS   : $IP"
    echo -e " Domain   : $(cat /etc/xray/domain 2>/dev/null || echo 'belum di-set')"
    echo -e " SSH      : 22, 109, 143"
    echo -e " Nginx    : 80, 443, 81"
    echo -e " Xray     : 10001-10008 (internal)"
    echo ""
    echo -e " ${C_YELLOW}Perintah utama:${C_RESET}"
    echo -e "   menu      → buka menu utama"
    echo -e "   addhost   → setting domain + SSL"
    echo -e "   verify    → verifikasi instalasi"
    echo -e "   xp        → hapus user expired manual"
    echo -e "   healthcheck → cek service"
    echo ""
    echo -e " ${C_YELLOW}UDP Custom (opsional):${C_RESET}"
    echo -e "   menu → [7] Utility → [12] Install UDP"
    echo ""
    echo -e " ${C_YELLOW}Reboot disarankan untuk memastikan semua service stabil.${C_RESET}"
    echo ""
}

# ============================================================
# EKSEKUSI INSTALASI
# ============================================================

first_setup
install_ssh
install_nginx
install_haproxy
install_xray
install_tools
install_udp_services
make_folders
download_lib
download_menu
download_config
init_xray_config
set_timezone
setup_cron
systemd_tuning
setup_logrotate
enable_services
set_hostname

# ---------- Setup domain (langsung tanpa prompt) ----------
echo ""
print_step "Setup Domain + SSL"
if [[ -x /usr/local/sbin/addhost ]]; then
    bash /usr/local/sbin/addhost < /dev/tty
else
    print_err "addhost tidak ditemukan, skip"
fi

final_info

echo ""
read -rp "Reboot sekarang? (y/N): " ans
if [[ "${ans,,}" == "y" ]]; then
    echo "Rebooting..."
    sleep 2
    reboot
fi
