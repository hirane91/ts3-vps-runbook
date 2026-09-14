#!/usr/bin/env bash
#
# Firewall: deny everything inbound, then open only what's needed.
#
# Note what is NOT opened: ServerQuery (10011 / 10022). Those stay bound to
# # 127.0.0.1 and you reach them over an SSH tunnel. See the README.
#
# Run as root. It will not lock you out of SSH, but read it first anyway.

set -euo pipefail

# Every UDP voice port you actually use. One per virtual server.
VOICE_PORTS=(9987)
FILETRANSFER_PORT=30033
TSDNS_PORT=41144

ufw default deny incoming
ufw default allow outgoing

ufw allow OpenSSH

for p in "${VOICE_PORTS[@]}"; do
  ufw allow "${p}/udp" comment "TeamSpeak voice"
done

ufw allow "${FILETRANSFER_PORT}/tcp" comment "TeamSpeak file transfer"
ufw allow "${TSDNS_PORT}/tcp" comment "TSDNS"

ufw --force enable
ufw status verbose
