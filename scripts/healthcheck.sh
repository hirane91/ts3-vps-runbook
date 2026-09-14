#!/usr/bin/env bash
#
# One command that answers "is everything still fine".
#
# The single most important line in the output is the newest
# auto-YYYY-MM-DD.sqlitedb date under BACKUPS. If that's several days old,
# your nightly backup has stopped and you didn't notice.

echo "=== TIME ==="
date
timedatectl | grep -i 'time zone'

echo
echo "=== SERVICES ==="
for svc in ts3server ufw fail2ban unattended-upgrades; do
  printf '%-22s %s\n' "$svc" "$(systemctl is-active "$svc" 2>/dev/null || echo 'not-found')"
done

echo
echo "=== NIGHTLY JOBS ==="
crontab -l 2>/dev/null || echo "(no root crontab)"
systemctl list-timers 'apt-daily*' --no-pager 2>/dev/null | head -5

echo
echo "=== AUTO REBOOT POLICY ==="
cat /etc/apt/apt.conf.d/51auto-reboot 2>/dev/null || echo "(not configured)"

echo
echo "=== BACKUPS ON BOX ==="
ls -lh /root/backups/ 2>/dev/null | tail -12 || echo "(none)"

echo
echo "=== BANNED IPS ==="
fail2ban-client status sshd 2>/dev/null | grep -E 'Currently banned|Total banned' || echo "(fail2ban not running)"

echo
echo "=== DISK ==="
df -h /

echo
echo "=== MEMORY ==="
free -h
