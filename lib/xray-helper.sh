#!/bin/bash
# ============================================================
# xray-helper.sh - Fungsi umum untuk kelola config.json
# Lokasi: /usr/local/sbin/xyr/lib/xray-helper.sh
# ============================================================

[[ -n "${_XYR_XRAY_HELPER_LOADED:-}" ]] && return 0
_XYR_XRAY_HELPER_LOADED=1

if [[ -z "${_XYR_COMMON_LOADED:-}" ]]; then
    _lib_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
    # shellcheck source=/dev/null
    source "$_lib_dir/common.sh"
fi

# ---------- Backup config ----------
xray_backup_config() {
    [[ -f "$XRAY_CONF" ]] || return 1
    cp -f "$XRAY_CONF" "${XRAY_CONF}.bak"
}

# ---------- Test config valid ----------
xray_validate() {
    if ! command -v xray >/dev/null 2>&1; then
        return 0
    fi
    xray -test -config "$XRAY_CONF" >/dev/null 2>&1
}

# ---------- Rollback kalau corrupt ----------
xray_rollback() {
    if [[ -f "${XRAY_CONF}.bak" ]]; then
        mv -f "${XRAY_CONF}.bak" "$XRAY_CONF"
        log_warn "Xray config rolled back"
        return 0
    fi
    return 1
}

# ---------- Validasi + rollback otomatis ----------
xray_apply() {
    if ! xray_validate; then
        xray_rollback
        restart_service xray
        return 1
    fi
    rm -f "${XRAY_CONF}.bak"
    restart_service xray
    return 0
}

# ---------- Sisip user baru ke config.json ----------
# Usage: xray_add_user PREFIX_TAG USERNAME EXP UUID [EXTRA_JSON]
#   PREFIX_TAG  : #vmess | #vmessgrpc | #vless | #vlessgrpc | #trojanws | #trojangrpc | #ssws | #ssgrpc
#   USERNAME    : username
#   EXP         : YYYY-MM-DD
#   UUID        : uuid/password
#   EXTRA_JSON  : tambahan json (mis. ,"alterId": 0)
xray_add_user() {
    local tag="$1" user="$2" exp="$3" uuid="$4" extra="${5:-}"
    local prefix="${6:-}"

    # Default prefix per tag
    if [[ -z "$prefix" ]]; then
        case "$tag" in
            *vmess*)  prefix="###" ;;
            *vless*)  prefix="#&" ;;
            *trojan*) prefix="#!" ;;
            *ss*)     prefix="#!#" ;;
            *)        prefix="###" ;;
        esac
    fi

    local line="{\"id\": \"${uuid}\",\"email\": \"${user}\"${extra}}"
    # Untuk SS dan Trojan beda format
    case "$tag" in
        *trojan*)
            line="{\"password\": \"${uuid}\",\"email\": \"${user}\"}"
            ;;
        *ss*)
            line="{\"password\": \"${uuid}\",\"method\": \"aes-128-gcm\",\"email\": \"${user}\"}"
            ;;
    esac

    # Sisip setelah tag
    sed -i "/${tag}\$/a\\${prefix} ${user} ${exp}\\
},${line}" "$XRAY_CONF"
}

# ---------- Hapus user dari config.json ----------
xray_del_user() {
    local prefix="$1" user="$2"
    local exp
    exp=$(grep -m1 "^${prefix} ${user} " "$XRAY_CONF" 2>/dev/null | cut -d ' ' -f 3)
    [[ -z "$exp" ]] && return 1
    sed -i "/^${prefix} ${user} ${exp}/,/^},{/d" "$XRAY_CONF"
    return 0
}

# ---------- Update DB ----------
db_save_user() {
    local db="$1" prefix="$2" user="$3" exp="$4" uuid="$5" quota="$6" iplimit="$7"
    [[ -f "$db" ]] || touch "$db"
    # Hapus baris lama kalau ada
    grep -qE "^${prefix} ${user} " "$db" && sed -i "/^${prefix} ${user} /d" "$db"
    echo "${prefix} ${user} ${exp} ${uuid} ${quota} ${iplimit}" >> "$db"
}

db_del_user() {
    local db="$1" prefix="$2" user="$3"
    [[ -f "$db" ]] && sed -i "/^${prefix} ${user} /d" "$db"
}

db_get_exp() {
    local db="$1" prefix="$2" user="$3"
    grep -m1 "^${prefix} ${user} " "$db" 2>/dev/null | awk '{print $3}'
}