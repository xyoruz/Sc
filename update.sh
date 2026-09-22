#!/bin/bash
# ============================================================
# update.sh - Update script dari GitHub (per-file, tanpa zip)
# ============================================================

# ---------- Identitas Repo ----------
REPO_USER="<user>"          # GANTI dengan username GitHub
REPO_NAME="<repo>"          # GANTI dengan nama repo
REPO_BRANCH="main"
REPO="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}"

# ---------- Warna ----------
C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'

# ---------- Cek root ----------
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo -e "${C_RED}[ERROR]${C_RESET} Jalankan sebagai root!"
    exit 1
fi

# ---------- Daftar file yang akan di-update ----------
FILES_LIB=(
    "lib/config.sh"
    "lib/common.sh"
    "lib/validate.sh"
)

FILES_MENU=(
    "menu/menu"
    "menu/m-ssh"
    "menu/m-vmess"
    "menu/m-vless"
    "menu/m-trojan"
    "menu/m-ss"
    "menu/m-sshws"
    "menu/m-noob"
    "menu/m-trial"
    "menu/m-bot"
    "menu/menu-backup"
    "menu/menu-x"
)

FILES_SSH=(
    "ssh/addssh"
    "ssh/delssh"
    "ssh/renewssh"
    "ssh/cekssh"
    "ssh/member"
    "ssh/trial"
    "ssh/lock"
    "ssh/unlock"
    "ssh/autokill"
    "ssh/ceklim"
    "ssh/delexp"
)

FILES_VMESS=(
    "vmess/addws"
    "vmess/delws"
    "vmess/renewws"
    "vmess/cekws"
    "vmess/trialws"
    "vmess/member-ws"
)

FILES_VLESS=(
    "vless/addvless"
    "vless/delvless"
    "vless/renewvless"
    "vless/cekvless"
    "vless/trialvless"
)

FILES_TROJAN=(
    "trojan/addtr"
    "trojan/deltr"
    "trojan/renewtr"
    "trojan/cektr"
    "trojan/trialtr"
)

FILES_SS=(
    "ss/addss"
    "ss/delss"
    "ss/renewss"
    "ss/cekss"
    "ss/trialss"
)

FILES_LIMIT=(
    "limit/limit-ip"
    "limit/limit-quota"
    "limit/lock-user"
    "limit/unlock-user"
    "limit/cek-lock"
    "limit/limitip-cron"
    "limit/limitquota-cron"
)

FILES_UTILITY=(
    "utility/xp"
    "utility/healthcheck"
    "utility/addhost"
    "utility/clearlog"
    "utility/clearcache"
    "utility/autoreboot"
    "utility/autokill"
    "utility/prot"
    "utility/bw"
    "utility/info"
    "utility/speedtest"
)

ALL_FILES=(
    "${FILES_LIB[@]}"
    "${FILES_MENU[@]}"
    "${FILES_SSH[@]}"
    "${FILES_VMESS[@]}"
    "${FILES_VLESS[@]}"
    "${FILES_TROJAN[@]}"
    "${FILES_SS[@]}"
    "${FILES_LIMIT[@]}"
    "${FILES_UTILITY[@]}"
)

# ---------- Fungsi download dengan retry ----------
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

# ---------- Eksekusi ----------
clear
echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
echo -e " ${C_YELLOW}UPDATE SCRIPT SEDANG BERJALAN...${C_RESET}"
echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
echo ""

TOTAL=${#ALL_FILES[@]}
OK_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

for path in "${ALL_FILES[@]}"; do
    name=$(basename "$path")

    # File library ditaruh di subfolder
    if [[ "$path" == lib/* ]]; then
        dest="/usr/local/sbin/xyr/${path}"
        perms="644"
    else
        dest="/usr/local/sbin/${name}"
        perms="755"
    fi

    printf "  %-25s " "$name"

    if safe_dl "${REPO}/${path}" "$dest"; then
        chmod "$perms" "$dest" 2>/dev/null
        echo -e "${C_GREEN}OK${C_RESET}"
        OK_COUNT=$((OK_COUNT + 1))
    else
        # Kalau download gagal, cek apakah file lama ada
        if [[ -f "$dest" ]]; then
            echo -e "${C_YELLOW}GAGAL (versi lama dipertahankan)${C_RESET}"
            SKIP_COUNT=$((SKIP_COUNT + 1))
        else
            echo -e "${C_RED}GAGAL${C_RESET}"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    fi
done

echo ""
echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
echo -e " ${C_GREEN}Update selesai${C_RESET}"
echo -e "   Sukses : $OK_COUNT"
echo -e "   Skip   : $SKIP_COUNT"
echo -e "   Gagal  : $FAIL_COUNT"
echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
echo ""

rm -f /root/update.sh 2>/dev/null

read -n 1 -s -r -p "Tekan [Enter] untuk kembali ke menu..."
if command -v menu >/dev/null 2>&1; then
    menu
fi