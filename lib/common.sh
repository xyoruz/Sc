#!/bin/bash
# ============================================================
# common.sh - Fungsi umum (warna, log, error handling, dll)
# Lokasi: /usr/local/sbin/xyr/lib/common.sh
# ============================================================

[[ -n "${_XYR_COMMON_LOADED:-}" ]] && return 0
_XYR_COMMON_LOADED=1

if [[ -z "${_XYR_CONFIG_LOADED:-}" ]]; then
    _lib_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    # shellcheck source=/dev/null
    source "$_lib_dir/config.sh"
fi

# ---------- Warna ----------
readonly C_RESET='\033[0m'
readonly C_RED='\033[1;31m'
readonly C_GREEN='\033[1;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[1;34m'
readonly C_PURPLE='\033[1;35m'
readonly C_CYAN='\033[1;36m'
readonly C_WHITE='\033[1;37m'
readonly C_GRAY='\033[1;30m'

# ---------- Print ----------
print_info()    { echo -e "${C_CYAN}[INFO]${C_RESET} $*"; }
print_ok()      { echo -e "${C_GREEN}[ OK ]${C_RESET} $*"; }
print_warn()    { echo -e "${C_YELLOW}[WARN]${C_RESET} $*"; }
print_error()   { echo -e "${C_RED}[FAIL]${C_RESET} $*" >&2; }
print_line()    { echo -e "${C_GRAY}─────────────────────────────────────────${C_RESET}"; }
print_title()   { echo -e "${C_PURPLE}$*${C_RESET}"; }

die() {
    print_error "$*"
    exit 1
}

# ---------- Logging ----------
log_write() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$ts] [$level] $msg" >> "$XYR_LOG/xyr.log"

    if [[ -f "$XYR_LOG/xyr.log" ]]; then
        local size
        size=$(stat -c%s "$XYR_LOG/xyr.log" 2>/dev/null || echo 0)
        if [[ $size -gt $LOG_MAX_SIZE ]]; then
            mv -f "$XYR_LOG/xyr.log" "$XYR_LOG/xyr.log.old"
        fi
    fi
}
log_info()  { log_write "INFO"  "$@"; }
log_warn()  { log_write "WARN"  "$@"; }
log_error() { log_write "ERROR" "$@"; }

# ---------- Lock ----------
acquire_lock() {
    local lockfile="$1"
    exec 9>"$lockfile"
    if ! flock -n 9; then
        print_error "Script lain sedang berjalan. Coba lagi nanti."
        exit 1
    fi
}
release_lock() {
    flock -u 9 2>/dev/null
    exec 9>&- 2>/dev/null
}

# ---------- Root ----------
require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        die "Script harus dijalankan sebagai root."
    fi
}

# ---------- Service ----------
is_service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}
service_exists() {
    systemctl list-unit-files --type=service 2>/dev/null \
        | awk '{print $1}' | grep -qx "${1}.service"
}
restart_service() {
    local svc="$1"
    if service_exists "$svc"; then
        systemctl restart "$svc" >/dev/null 2>&1
    fi
}
reload_service() {
    local svc="$1"
    if service_exists "$svc"; then
        systemctl reload "$svc" >/dev/null 2>&1 || systemctl restart "$svc" >/dev/null 2>&1
    fi
}

# ---------- Download ----------
safe_download() {
    local url="$1" out="$2"
    local try=0
    while [[ $try -lt $RETRY_MAX ]]; do
        if curl -fsSL --max-time "$CURL_TIMEOUT" "$url" -o "$out"; then
            return 0
        fi
        try=$((try + 1))
        sleep 2
    done
    return 1
}

# ---------- IP & Domain ----------
get_my_ip() {
    local ip
    ip=$(curl -sS --max-time 5 https://ipv4.icanhazip.com 2>/dev/null)
    if [[ -z "$ip" ]]; then
        ip=$(curl -sS --max-time 5 https://api.ipify.org 2>/dev/null)
    fi
    echo "$ip"
}
get_domain() {
    [[ -f "$XRAY_DOMAIN" ]] && cat "$XRAY_DOMAIN"
}

# ---------- Xray ----------
xray_test_config() {
    local cfg="${1:-$XRAY_CONF}"
    if ! command -v xray >/dev/null 2>&1; then
        return 0
    fi
    xray -test -config "$cfg" >/dev/null 2>&1
}
backup_config() {
    local cfg="${1:-$XRAY_CONF}"
    [[ -f "$cfg" ]] || return 1
    cp -f "$cfg" "${cfg}.bak"
}
restore_config() {
    local cfg="${1:-$XRAY_CONF}"
    [[ -f "${cfg}.bak" ]] || return 1
    mv -f "${cfg}.bak" "$cfg"
}

# ---------- Auto-lock ----------
autolock_enabled() {
    [[ -f "$AUTOLOCK_FILE" ]] && grep -qx "ON" "$AUTOLOCK_FILE"
}
autolock_set() {
    local val="${1^^}"
    [[ "$val" == "ON" || "$val" == "OFF" ]] || return 1
    echo "$val" > "$AUTOLOCK_FILE"
}

# ---------- Human Size ----------
human_size() {
    local bytes="$1"
    if [[ $bytes -lt 1024 ]]; then
        echo "${bytes}B"
    elif [[ $bytes -lt 1048576 ]]; then
        echo "$(( bytes / 1024 ))KB"
    elif [[ $bytes -lt 1073741824 ]]; then
        echo "$(( bytes / 1048576 ))MB"
    else
        echo "$(( bytes / 1073741824 ))GB"
    fi
}

# ---------- Header ----------
print_header() {
    local title="$1"
    clear
    print_line
    print_title "   $title"
    print_line
}

# ---------- Menu ----------
back_to_menu() {
    echo ""
    read -rp "Tekan [Enter] untuk kembali ke menu..."
    if command -v menu >/dev/null 2>&1; then
        menu
    fi
}
