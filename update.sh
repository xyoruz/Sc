#!/bin/bash
# ============================================================
# update.sh - Update autoscript dari GitHub (per-file)
# Konsisten dengan prem.sh
# ============================================================

REPO_USER="xyoruz"
REPO_NAME="Sc"
REPO_BRANCH="main"
REPO="https://raw.githubusercontent.com/${REPO_USER}/${REPO_NAME}/${REPO_BRANCH}"

# ---------- Cek root ----------
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo -e "\033[1;31m[ERROR]\033[0m Jalankan sebagai root!"
    exit 1
fi

C_RESET='\033[0m'
C_RED='\033[1;31m'
C_GREEN='\033[1;32m'
C_YELLOW='\033[1;33m'
C_CYAN='\033[1;36m'

OK="${C_GREEN}--->${C_RESET}"
ERR="${C_RED}[ERROR]${C_RESET}"

print_step() {
    echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
    echo -e "${C_YELLOW} $1 ${C_RESET}"
    echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
    sleep 0.5
}

# ---------- Download helper ----------
safe_dl() {
    local url="$1" dest="$2"
    local tmp
    tmp="$(mktemp)" || return 1

    local try=0
    while [[ $try -lt 3 ]]; do
        if curl -fsSL --max-time 20 \
            -H "Cache-Control: no-cache" \
            "$url" -o "$tmp" 2>/dev/null; then

            if [[ -s "$tmp" ]] && \
               ! head -c 300 "$tmp" | grep -qiE '<!DOCTYPE|<html|404: Not Found'; then
                mv -f "$tmp" "$dest"
                return 0
            fi
        fi
        try=$((try + 1))
        sleep 1
    done
    rm -f "$tmp"
    return 1
}

# ============================================================
# DAFTAR FILE (konsisten dengan prem.sh)
# ============================================================

FILES_LIB=(
    "config.sh"
    "common.sh"
    "validate.sh"
    "xray-helper.sh"
)

FILES_MENU=(
    "menu"
    "m-ssh" "m-vmess" "m-vless" "m-trojan" "m-ss"
    "m-trial" "m-utility" "m-limit" "m-bot"
    "menu-backup" "menu-x"
)

FILES_SSH=(
    "addssh" "delssh" "renewssh" "cekssh"
    "member" "trial" "lock" "unlock"
    "autokill" "ceklim" "delexp"
    "delssh-auto" "tendang"
)

FILES_VMESS=(
    "addws" "delws" "renewws" "cekws"
    "trialws" "member-ws"
)

FILES_VLESS=(
    "addvless" "delvless" "renewvless" "cekvless" "trialvless"
)

FILES_TROJAN=(
    "addtr" "deltr" "renewtr" "cektr" "trialtr"
)

FILES_SS=(
    "addss" "delss" "renewss" "cekss" "trialss"
)

FILES_LIMIT=(
    "limit-ip" "limit-quota"
    "lock-user" "unlock-user" "cek-lock"
    "limitip-cron" "limitquota-cron"
)

FILES_UTILITY=(
    "xp" "healthcheck"
    "addhost" "clearlog" "clearcache"
    "autoreboot" "autokill"
    "prot" "bw" "info" "speedtest"
    "del-auto"
    "init-config"
    "verify"
    "install-udp"
    "install-udp-custom"
    "uninstall-udp"
)

# ============================================================
# EKSEKUSI
# ============================================================

clear
echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
echo -e " ${C_YELLOW}UPDATE AUTOSCRIPT XYR${C_RESET}"
echo -e " ${C_CYAN}Repo   :${C_RESET} ${REPO_USER}/${REPO_NAME}"
echo -e " ${C_CYAN}Branch :${C_RESET} ${REPO_BRANCH}"
echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
echo ""

mkdir -p /usr/local/sbin/xyr/lib

OK_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# ---------- 1. Library ----------
print_step "Update Library"
for f in "${FILES_LIB[@]}"; do
    dest="/usr/local/sbin/xyr/lib/${f}"
    printf "  %-28s " "lib/${f}"
    if safe_dl "${REPO}/lib/${f}" "$dest"; then
        chmod 644 "$dest"
        echo -e "${C_GREEN}OK${C_RESET}"
        OK_COUNT=$((OK_COUNT + 1))
    else
        [[ -f "$dest" ]] && { echo -e "${C_YELLOW}SKIP${C_RESET}"; SKIP_COUNT=$((SKIP_COUNT+1)); } \
                         || { echo -e "${C_RED}FAIL${C_RESET}"; FAIL_COUNT=$((FAIL_COUNT+1)); }
    fi
done

# ---------- 2. Fungsi update per grup ----------
update_group() {
    local folder="$1"; shift
    local files=("$@")
    for f in "${files[@]}"; do
        dest="/usr/local/sbin/${f}"
        printf "  %-28s " "${folder}/${f}"
        if safe_dl "${REPO}/${folder}/${f}" "$dest"; then
            chmod 755 "$dest"
            echo -e "${C_GREEN}OK${C_RESET}"
            OK_COUNT=$((OK_COUNT + 1))
        else
            [[ -f "$dest" ]] && { echo -e "${C_YELLOW}SKIP${C_RESET}"; SKIP_COUNT=$((SKIP_COUNT+1)); } \
                             || { echo -e "${C_RED}FAIL${C_RESET}"; FAIL_COUNT=$((FAIL_COUNT+1)); }
        fi
    done
}

# ---------- 3. Menu ----------
print_step "Update Menu"
update_group "menu" "${FILES_MENU[@]}"

# ---------- 4. SSH ----------
print_step "Update SSH"
update_group "ssh" "${FILES_SSH[@]}"

# ---------- 5. VMess ----------
print_step "Update VMess"
update_group "vmess" "${FILES_VMESS[@]}"

# ---------- 6. VLESS ----------
print_step "Update VLESS"
update_group "vless" "${FILES_VLESS[@]}"

# ---------- 7. Trojan ----------
print_step "Update Trojan"
update_group "trojan" "${FILES_TROJAN[@]}"

# ---------- 8. Shadowsocks ----------
print_step "Update Shadowsocks"
update_group "ss" "${FILES_SS[@]}"

# ---------- 9. Limit ----------
print_step "Update Limit"
update_group "limit" "${FILES_LIMIT[@]}"

# ---------- 10. Utility ----------
print_step "Update Utility"
update_group "utility" "${FILES_UTILITY[@]}"

# ---------- Restart service terkait ----------
print_step "Restart Service"
for svc in xray nginx haproxy dropbear ssh cron; do
    systemctl restart "$svc" 2>/dev/null && \
        echo -e "  ${OK} restart ${svc}" || true
done

# ---------- Ringkasan ----------
echo ""
echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
echo -e " ${C_GREEN}Update selesai${C_RESET}"
echo -e "   Sukses : $OK_COUNT"
echo -e "   Skip   : $SKIP_COUNT"
echo -e "   Gagal  : $FAIL_COUNT"
echo -e "${C_CYAN}════════════════════════════════════════════${C_RESET}"
echo ""

read -n 1 -s -r -p "Tekan [Enter] untuk kembali ke menu..."
if command -v menu >/dev/null 2>&1; then
    menu
fi

exit 0
