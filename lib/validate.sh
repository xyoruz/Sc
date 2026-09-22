#!/bin/bash
# ============================================================
# validate.sh - Validasi input user
# Lokasi: /usr/local/sbin/xyr/lib/validate.sh
# ============================================================

[[ -n "${_XYR_VALIDATE_LOADED:-}" ]] && return 0
_XYR_VALIDATE_LOADED=1

if [[ -z "${_XYR_COMMON_LOADED:-}" ]]; then
    _lib_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    # shellcheck source=/dev/null
    source "$_lib_dir/common.sh"
fi

# ---------- Validasi ----------
is_valid_username() {
    local u="$1"
    [[ "$u" =~ ^[a-z_][a-z0-9_]{0,31}$ ]]
}

is_valid_domain() {
    local d="$1"
    [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$ ]]
}

is_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

# ---------- Prompt ----------
ask_username() {
    local __var="$1"
    local prompt="${2:-Username}"
    local input
    while :; do
        read -rp " $prompt: " input
        if [[ -z "$input" ]]; then
            print_error "Tidak boleh kosong."
            continue
        fi
        if ! is_valid_username "$input"; then
            print_error "Username hanya huruf kecil, angka, underscore. Maks 32 karakter."
            continue
        fi
        if getent passwd "$input" >/dev/null 2>&1; then
            print_error "User '$input' sudah ada di sistem."
            continue
        fi
        printf -v "$__var" '%s' "$input"
        return 0
    done
}

ask_password() {
    local __var="$1"
    local prompt="${2:-Password}"
    local p1 p2
    while :; do
        read -rsp " $prompt: " p1; echo
        if [[ -z "$p1" ]]; then
            print_error "Password tidak boleh kosong."
            continue
        fi
        read -rsp " Konfirmasi Password: " p2; echo
        if [[ "$p1" != "$p2" ]]; then
            print_error "Password tidak sama."
            continue
        fi
        printf -v "$__var" '%s' "$p1"
        return 0
    done
}

ask_number() {
    local __var="$1"
    local prompt="$2"
    local min="${3:-0}"
    local max="${4:-999999}"
    local def="${5:-}"
    local input
    while :; do
        if [[ -n "$def" ]]; then
            read -rp " $prompt [$def]: " input
            [[ -z "$input" ]] && input="$def"
        else
            read -rp " $prompt: " input
        fi
        if ! is_number "$input"; then
            print_error "Harus berupa angka."
            continue
        fi
        if (( input < min || input > max )); then
            print_error "Nilai harus antara $min dan $max."
            continue
        fi
        printf -v "$__var" '%s' "$input"
        return 0
    done
}

ask_domain() {
    local __var="$1"
    local prompt="${2:-Domain}"
    local input
    while :; do
        read -rp " $prompt: " input
        if ! is_valid_domain "$input"; then
            print_error "Format domain tidak valid."
            continue
        fi
        printf -v "$__var" '%s' "$input"
        return 0
    done
}

ask_yesno() {
    local __var="$1"
    local prompt="$2"
    local def="${3:-n}"
    local input
    read -rp " $prompt (y/n) [$def]: " input
    [[ -z "$input" ]] && input="$def"
    case "${input,,}" in
        y|yes) printf -v "$__var" 'y' ;;
        *)     printf -v "$__var" 'n' ;;
    esac
}

# ---------- Cek User ----------
user_exists_in_config() {
    local user="$1"
    grep -qw "$user" "$XRAY_CONF" 2>/dev/null
}

user_exists_in_db() {
    local user="$1"
    local db="$2"
    [[ -f "$db" ]] && grep -qE "^[^ ]+ ${user} " "$db" 2>/dev/null
}
