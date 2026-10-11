#!/bin/bash
# ==========================================
# Script Uninstall NEXUS TUNNELING (v4.0 NEXUS)
# [PATCH] Cleanup lengkap semua komponen
# ==========================================

echo -e "\e[33mMemulai proses uninstall NEXUS TUNNELING...\e[0m"

# Hentikan semua layanan
systemctl stop xray haproxy nexus-daemon 2>/dev/null
systemctl disable xray haproxy nexus-daemon 2>/dev/null
systemctl stop telegram-webhook.socket 2>/dev/null
systemctl disable telegram-webhook.socket 2>/dev/null

# Hapus file konfigurasi dan database
umount -f /var/log/xray 2>/dev/null
rm -rf /usr/local/etc/xray /etc/haproxy /etc/nexustunnel /etc/xray /var/log/xray

# Hapus file executable menu & daemon
rm -f /usr/local/sbin/algojo-nexus /usr/local/sbin/algojo-kuota /usr/local/sbin/unlocker-nexus
rm -f /usr/local/bin/menu /usr/local/bin/m-vless /usr/local/bin/m-vmess /usr/local/bin/m-trojan
rm -f /usr/local/bin/m-setting /usr/local/bin/m-backup /usr/local/bin/menu-lock /usr/local/bin/menu-unlock
rm -f /usr/local/bin/menu-recovery /usr/local/bin/cek-trafik /usr/local/bin/xp
rm -f /usr/local/bin/lock-user /usr/local/bin/unlock-user
rm -f /usr/local/bin/bot-daemon /usr/local/bin/bot-webhook
rm -f /usr/local/bin/nexus-daemon /usr/local/bin/watchdog.sh /usr/local/bin/renew-cert-nexus.sh
rm -f /usr/local/bin/common.sh

# Bersihkan Cron Jobs bawaan Nexus Tunneling
crontab -l 2>/dev/null | grep -v -E 'watchdog\.sh|/usr/local/bin/xp|unlocker-nexus|renew-cert-nexus|algojo|drop_caches.*swapon|/sbin/reboot' | crontab -

# Hapus service systemd
rm -f /etc/systemd/system/nexus-daemon.service
rm -f /etc/systemd/system/telegram-webhook.socket
rm -f /etc/systemd/system/telegram-webhook@.service
rm -rf /etc/systemd/system/haproxy.service.d
rm -rf /etc/systemd/system/xray.service.d
rm -f /etc/systemd/system/nexustunnel-bot.service /etc/systemd/system/xray.service /etc/systemd/system/xray@.service
systemctl daemon-reload

# Hapus logrotate
rm -f /etc/logrotate.d/xray

# Bersihkan .profile
sed -i '/^clear$/d; /^menu$/d' /root/.profile 2>/dev/null
sed -i '/\/var\/log\/xray/d' /etc/fstab 2>/dev/null

# Uninstall paket bawaan (opsional)
apt-get remove --purge -y haproxy vnstat jq >/dev/null 2>&1
apt-get autoremove -y >/dev/null 2>&1

echo -e "\e[32mUninstalasi Selesai! VPS sudah bersih dari NEXUS TUNNELING.\e[0m"
