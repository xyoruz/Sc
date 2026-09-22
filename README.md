# XyrVPN — Autoscript Xray

Autoscript Xray untuk **Debian & Ubuntu** dengan fitur Vmess, Vless, Trojan, Shadowsocks, SSH/OpenVPN.

---

## 📌 Fitur

- Vmess (WS + gRPC)
- Vless (WS + gRPC)
- Trojan (WS + gRPC)
- Shadowsocks (WS + gRPC)
- SSH / OpenVPN
- SSL otomatis (acme.sh)
- Limit IP per user
- Limit Quota per user
- Auto-lock IP & Quota
- Lock / Unlock manual
- Trial account (menit)
- Auto-delete expired
- Health check service
- Auto-reboot scheduler
- Bandwidth monitor (vnstat)
- Speedtest

---

## 💻 OS Support

| Distro | Versi |
|--------|-------|
| Ubuntu | 20.04, 22.04, 24.04 |
| Debian | 10, 11, 12 |

**Arsitektur:** x86_64
**Virtualisasi:** KVM / Xen / VMware (OpenVZ **tidak didukung**)

---

## 🖥️ Spesifikasi VPS

| Komponen | Minimal |
|----------|---------|
| CPU | 1 core |
| RAM | 1 GB |
| Disk | 10 GB |
| OS | Ubuntu 20.04 / Debian 10 |

---

## 🚀 Instalasi

```bash
apt update -y && apt upgrade -y && \
wget -q https://raw.githubusercontent.com/<user>/<repo>/main/prem.sh && \
chmod +x prem.sh && ./prem.sh
```

Ganti `<user>` dan `<repo>` dengan milikmu.

---

## ⚙️ Setup Setelah Instalasi

**1. Setting domain + SSL:**
```bash
addhost
```

**2. Verifikasi:**
```bash
verify
```

**3. Buka menu:**
```bash
menu
```

---

## 🧪 Verifikasi Total

```bash
verify
```

Atau manual:

```bash
# Cek service
for svc in xray nginx ssh dropbear cron; do
    printf "%-12s : %s\n" "$svc" "$(systemctl is-active $svc)"
done

# Cek config
xray -test -config /etc/xray/config.json
nginx -t
sshd -t

# Cek port
ss -tlnp | grep -E ":(22|80|81|109|143|443|1000[0-9])\b"

# Cek folder
ls -la /etc/xyr/
ls -la /usr/local/sbin/xyr/lib/
```

---

## 🛠️ Command Utama

| Command | Fungsi |
|---------|--------|
| `menu` | Menu utama |
| `addhost` | Setting domain + SSL |
| `addssh` | Create SSH |
| `addws` | Create Vmess |
| `addvless` | Create Vless |
| `addtr` | Create Trojan |
| `addss` | Create Shadowsocks |
| `delws`, `delvless`, `deltr`, `delss`, `delssh` | Hapus user |
| `renewws`, `renewvless`, `renewtr`, `renewss`, `renewssh` | Perpanjang user |
| `cekws`, `cekvless`, `cektr`, `cekss`, `cekssh` | Cek user |
| `trial`, `trialws`, `trialvless`, `trialtr`, `trialss` | Trial account |
| `limit-ip` | Atur limit IP |
| `limit-quota` | Atur limit quota |
| `lock-user` | Lock manual |
| `unlock-user` | Unlock manual |
| `cek-lock` | Lihat user ter-lock |
| `xp` | Auto-delete expired |
| `healthcheck` | Cek & restart service |
| `verify` | Verifikasi instalasi |
| `info` | Info server |
| `bw` | Bandwidth monitor |
| `speedtest` | Test kecepatan |
| `autoreboot` | Scheduler reboot |
| `clearlog` | Bersihkan log |
| `clearcache` | Bersihkan cache RAM |
| `update` | Update script |

---

## 🔒 Auto-Lock

Default: **OFF**. Nyalakan via menu → Limit → `[7]`.

**Cara kerja:**

| Cron | Frekuensi | Fungsi |
|------|-----------|--------|
| `limitip-cron` | 1 menit | Cek IP, lock kalau > limit |
| `limitquota-cron` | 5 menit | Cek quota, lock kalau terlampaui |
| `xp` | 1 jam | Hapus user expired |
| `healthcheck` | 10 menit | Restart service yang mati |

Lock = suspend. Bisa di-unlock kapan saja.

---

## 📂 Struktur Data

```
/etc/xyr/
├── db/                    ← database user
├── quota/<service>/       ← limit quota
├── limit/<service>/       ← limit IP
├── usage/<service>/       ← pemakaian
├── locked/<service>/      ← status lock
└── autolock               ← ON/OFF

/usr/local/sbin/
├── menu, addws, addvless, ...
└── xyr/lib/               ← library
```

---

## 🐛 Troubleshooting

**Xray gagal start:**
```bash
journalctl -u xray -n 30 --no-pager
xray -test -config /etc/xray/config.json
```

**Nginx gagal start:**
```bash
nginx -t
```

**Tidak bisa SSH:**
Login via console VPS:
```bash
cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
systemctl restart ssh
```

**Auto-lock tidak jalan:**
```bash
cat /etc/xyr/autolock
ls /etc/cron.d/xyr-*
```

---

## 🔄 Update

```bash
update
```

---

## 👤 Author

**Xyr** — [@xyr](https://t.me/xyr)