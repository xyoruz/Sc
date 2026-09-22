# Xray
xray -test -config /etc/xray/config.json
systemctl status xray

# Nginx
nginx -t
systemctl status nginx

# SSH
sshd -t
systemctl status ssh

# Dropbear
systemctl status dropbear

# HAProxy (kalau dipakai)
haproxy -c -f /etc/haproxy/haproxy.cfg
systemctl status haproxy