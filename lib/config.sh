#!/bin/bash
# ============================================================
# config.sh - Konstanta global script XyrVPN
# Lokasi: /usr/local/sbin/xyr/lib/config.sh
# Fungsi: menyimpan semua path, port, prefix, dan setting tetap
# ============================================================

# ---------- Guard: jangan di-source 2x ----------
[[ -n "${_XYR_CONFIG_LOADED:-}" ]] && return 0
_XYR_CONFIG_LOADED=1

# ---------- Identitas Script ----------
readonly XYR_NAME="XyrVPN"
readonly XYR_AUTHOR="Xyr"
readonly XYR_VERSION="1.0.0"
readonly XYR_TELEGRAM="@xyr"
readonly XYR_BASE="/usr/local/sbin/xyr"

# ---------- Path Utama ----------
readonly XYR_CONF="/etc/xyr"
readonly XYR_LOG="/var/log/xyr"
readonly XYR_BACKUP="/var/backups/xyr"

# ---------- Path Layanan ----------
readonly XRAY_CONF="/etc/xray/config.json"
readonly XRAY_DOMAIN="/etc/xray/domain"
readonly XRAY_LOG="/var/log/xray/access.log"
readonly XRAY_API="127.0.0.1:10085"
readonly NGINX_WEB="/var/www/html"

# ---------- Path Data Per Layanan ----------
readonly DB_VMESS="/etc/xyr/db/vmess.db"
readonly DB_VLESS="/etc/xyr/db/vless.db"
readonly DB_TROJAN="/etc/xyr/db/trojan.db"
readonly DB_SS="/etc/xyr/db/shadowsocks.db"
readonly DB_SSH="/etc/xyr/db/ssh.db"

readonly QUOTA_DIR="/etc/xyr/quota"
readonly LIMITIP_DIR="/etc/xyr/limit"
readonly USAGE_DIR="/etc/xyr/usage"
readonly LOCKED_DIR="/etc/xyr/locked"
readonly AUTOLOCK_FILE="/etc/xyr/autolock"

# ---------- Prefix Config.json ----------
readonly PREFIX_VMESS="###"
readonly PREFIX_VLESS="#&"
readonly PREFIX_TROJAN="#!"
readonly PREFIX_SS="#!#"
readonly PREFIX_SSH="#ssh#"

# ---------- Port Default ----------
readonly PORT_SSH="22"
readonly PORT_SSH_WS="80"
readonly PORT_SSH_SSL="443"
readonly PORT_DROPBEAR="109,143"
readonly PORT_OVPN_TCP="1194"
readonly PORT_OVPN_UDP="2200"
readonly PORT_XRAY_TLS="443"
readonly PORT_XRAY_NTLS="80"
readonly PORT_XRAY_GRPC="443"

# ---------- Service Name ----------
readonly SERVICE_XRAY="xray"
readonly SERVICE_NGINX="nginx"
readonly SERVICE_HAPROXY="haproxy"
readonly SERVICE_SSH="ssh"
readonly SERVICE_DROPBEAR="dropbear"
readonly SERVICE_WS="ws"
readonly SERVICE_CRON="cron"

# ---------- Lock File ----------
readonly LOCKFILE_ADD="/var/lock/xyr-add.lock"
readonly LOCKFILE_DEL="/var/lock/xyr-del.lock"
readonly LOCKFILE_CRON="/var/lock/xyr-cron.lock"

# ---------- Setting Umum ----------
readonly RETRY_MAX=3
readonly CURL_TIMEOUT=15
readonly LOG_MAX_SIZE=5242880

# ---------- Buat Folder Otomatis ----------
for d in \
    "$XYR_CONF" "$XYR_LOG" "$XYR_BACKUP" \
    "$QUOTA_DIR" "$LIMITIP_DIR" "$USAGE_DIR" "$LOCKED_DIR" \
    "$(dirname "$DB_VMESS")" \
    "$QUOTA_DIR/vmess" "$QUOTA_DIR/vless" "$QUOTA_DIR/trojan" "$QUOTA_DIR/ss" "$QUOTA_DIR/ssh" \
    "$LIMITIP_DIR/vmess" "$LIMITIP_DIR/vless" "$LIMITIP_DIR/trojan" "$LIMITIP_DIR/ss" "$LIMITIP_DIR/ssh" \
    "$USAGE_DIR/vmess" "$USAGE_DIR/vless" "$USAGE_DIR/trojan" "$USAGE_DIR/ss" "$USAGE_DIR/ssh" \
    "$LOCKED_DIR/vmess" "$LOCKED_DIR/vless" "$LOCKED_DIR/trojan" "$LOCKED_DIR/ss" "$LOCKED_DIR/ssh" \
    ; do
    [[ -d "$d" ]] || mkdir -p "$d"
done

# ---------- File Default ----------
[[ -f "$DB_VMESS"  ]] || touch "$DB_VMESS"
[[ -f "$DB_VLESS"  ]] || touch "$DB_VLESS"
[[ -f "$DB_TROJAN" ]] || touch "$DB_TROJAN"
[[ -f "$DB_SS"     ]] || touch "$DB_SS"
[[ -f "$DB_SSH"    ]] || touch "$DB_SSH"
[[ -f "$AUTOLOCK_FILE" ]] || echo "OFF" > "$AUTOLOCK_FILE"
