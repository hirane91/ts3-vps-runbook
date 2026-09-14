#!/usr/bin/env bash
#
# Hot backup of the TeamSpeak SQLite database.
#
# Uses sqlite3's .backup command, which takes a consistent snapshot of a live
# database. TeamSpeak keeps running and nobody gets disconnected. Do NOT just
# cp the .sqlitedb file while the server is up, you can get a torn copy.
#
# Install:
#   apt install -y sqlite3
#   cp ts3-backup.sh /root/ts3-backup.sh && chmod 700 /root/ts3-backup.sh
#   crontab -e     ->   0 4 * * * /root/ts3-backup.sh
#
# Cron uses the server's timezone. Check it with `timedatectl` before you
# assume 04:00 means 04:00 where you live.

set -euo pipefail

TS_DIR="/home/ts/teamspeak3-server_linux_amd64"
DB="${TS_DIR}/ts3server.sqlitedb"
DEST="/root/backups"
KEEP_DAYS=7

[ -f "$DB" ] || { echo "database not found at $DB" >&2; exit 1; }
mkdir -p "$DEST"

OUT="${DEST}/auto-$(date +%F).sqlitedb"
sqlite3 "$DB" ".backup '${OUT}'"

# Only ever deletes files matching auto-*.sqlitedb, so manual backups you named
# something else (premigration, pre-upgrade, whatever) are safe from it.
find "$DEST" -maxdepth 1 -type f -name 'auto-*.sqlitedb' -mtime "+${KEEP_DAYS}" -delete

echo "$(date '+%F %T') wrote ${OUT} ($(du -h "$OUT" | cut -f1))"
