# ts3-vps-runbook

Running a TeamSpeak 3 server on a cheap VPS, written down properly.

There are plenty of one-command TeamSpeak installers on GitHub already. They work. What they don't tell you is which VPS to put it on, how to back up the database without kicking everyone off, how to patch the box without it silently breaking, or how to lock down ServerQuery so your admin password isn't sitting in `ps` output.

That's what this is. Less an installer, more a runbook. It came out of migrating a community server that had been running unattended for years and was quietly broken in four different ways.

## Who this is for

You want to host voice comms for a gaming community or a small org, you have shell access to a $5 to $10 VPS, and you'd rather set it up once and not think about it again.

You do not need to be a sysadmin. You do need to be comfortable pasting commands into SSH and reading the output.

If you are starting from nothing, go straight to [Start here](#start-here) and read the rest afterwards.

## Start here

If you have never done this, follow these in order. Nothing later works without the step before it. Budget an hour.

### 1. Get a VPS with a good route to your users

Pick any provider that bills hourly. Deploy the cheapest instance in the region you think is right, with **Ubuntu 22.04 LTS**, then ping it from your own connection before doing anything else.

If the latency is bad, destroy the instance and deploy a new one. You will get a different address, possibly in a different block, possibly much faster. Repeat until the number is good. This costs cents and it is the single highest leverage thing in this whole document. Read the section below on why.

Everything after this assumes you can `ssh root@YOUR_SERVER_IP` and you are looking at a shell.

### 2. Basic setup

```bash
apt update && apt upgrade -y
apt install -y sqlite3 bzip2
timedatectl set-timezone YOUR/TIMEZONE     # e.g. Europe/Berlin
```

Set the timezone now, before you schedule anything. Cron and systemd timers use it, and it is confusing to discover later that your "4am" backup runs at noon.

If the box has 1 GB of RAM, add swap:

```bash
fallocate -l 3G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

### 3. Install TeamSpeak

Never run it as root. Give it its own unprivileged user:

```bash
adduser --disabled-login --gecos "" ts
su - ts
```

Get the current server download URL from teamspeak.com, then as the `ts` user:

```bash
wget PASTE_THE_URL_HERE
tar -xjf teamspeak3-server_linux_amd64-*.tar.bz2
cd teamspeak3-server_linux_amd64
touch .ts3server_license_accepted
```

### 4. First start, and the one thing you must not miss

```bash
./ts3server_startscript.sh start
```

It prints a **serveradmin password** and a **privilege key** once, and never again. Copy both somewhere safe right now. The privilege key is what makes your own client the server admin the first time you connect.

Connect with the TeamSpeak client to `YOUR_SERVER_IP`, paste the privilege key when prompted, and confirm you can talk. Then stop it:

```bash
./ts3server_startscript.sh stop
exit    # back to root
```

### 5. Move the settings into a config file

Still as `ts`, create `ts3server.ini` in the server folder:

```ini
machine_id=
default_voice_port=9987
voice_ip=0.0.0.0
filetransfer_port=30033
filetransfer_ip=0.0.0.0
query_port=10011
query_ip=127.0.0.1
query_ssh_port=10022
query_ssh_ip=127.0.0.1
dbsqlpath=sql/
dbplugin=ts3db_sqlite3
dbsqlcreatepath=create_sqlite/
logpath=logs
licensepath=
serveradmin_password=PUT_A_STRONG_PASSWORD_HERE
```

Then lock it down, because it now contains a password:

```bash
chmod 600 /home/ts/teamspeak3-server_linux_amd64/ts3server.ini
```

The two `query_ip=127.0.0.1` lines are the important ones. They stop ServerQuery from listening on the internet.

### 6. Make it survive reboots

Copy [`scripts/ts3server.service`](scripts/ts3server.service) to `/etc/systemd/system/ts3server.service`, then as root:

```bash
systemctl daemon-reload
systemctl enable --now ts3server
systemctl status ts3server
```

Reboot the box and check it comes back up on its own. A server that only starts when you start it by hand will be dead the next time the machine restarts and you will not find out for weeks.

### 7. Firewall

Edit [`scripts/ufw-rules.sh`](scripts/ufw-rules.sh) so `VOICE_PORTS` lists every voice port you use, then run it as root. Confirm you can still connect with your client afterwards.

### 8. Backups

```bash
cp scripts/ts3-backup.sh /root/ts3-backup.sh
chmod 700 /root/ts3-backup.sh
/root/ts3-backup.sh          # run it once by hand, check it works
crontab -e                   # add:  0 4 * * * /root/ts3-backup.sh
```

### 9. Automatic security patching

```bash
apt install -y unattended-upgrades
cat > /etc/apt/apt.conf.d/51auto-reboot <<'EOF'
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "05:00";
EOF
```

Ubuntu's default config already restricts this to the security pocket. The reboot only happens on nights when a patch actually requires one.

### 10. fail2ban, if SSH accepts passwords

```bash
apt install -y fail2ban
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
bantime   = 1h
findtime  = 10m
maxretry  = 5
banaction = ufw

[sshd]
enabled  = true
port     = ssh
maxretry = 4
bantime  = 24h
EOF
systemctl enable --now fail2ban
fail2ban-client status sshd
```

Expect bans within minutes. That is not a sign something is wrong, it is what port 22 looks like on the public internet.

### 11. Check your work

Copy [`scripts/healthcheck.sh`](scripts/healthcheck.sh) to the box and run it. Everything should be `active`, the backup file should be today's, and the disk should be nowhere near full. Run it once a month.

Then do the thing everyone skips: copy a backup off the server onto your own machine. A backup that only exists on the server is not a backup.

## The one thing most guides get wrong

Pick the host by measuring latency, not by reading the datacentre location.

Two servers in the same building, same provider, can be 160 ms apart for your users. Providers own multiple IP blocks and ISPs route them completely differently. Real numbers from one migration, all three addresses in the same provider's Singapore datacentre, measured from the same consumer connection:

| Provider IP block | Ping |
|---|---|
| Block A | 82 ms |
| Block B | 244 ms |
| Block C | 255 ms |

Same provider. Same city. Same building. Three times the latency depending on which address you happen to get assigned.

Worse, the provider's own looking-glass and speedtest endpoints lie to you. They sit in different IP ranges from customer instances. One provider's test host answered in 81 ms while a real server of theirs in that same datacentre answered in 244 ms.

Most VPS providers bill by the hour, so use that. Deploy a real instance, ping it from where your users actually are, and if the number is bad, destroy it and deploy again until you land in a block that routes well. It costs cents. Do this **before** you invest an evening in setup.

Two corollaries worth knowing:

- Nearer is not faster. On that same connection, every Indian datacentre tested lost to Singapore, by 100 ms or more in some cases. Routing beats distance.
- Test from the kind of connection your users have, not from a cloud shell or a speed test site.

## What's in here

- [`scripts/ts3server.service`](scripts/ts3server.service) systemd unit, runs TeamSpeak as an unprivileged user and brings it back after a reboot
- [`scripts/ts3-backup.sh`](scripts/ts3-backup.sh) nightly hot backup of the SQLite database, 7 day rotation
- [`scripts/ufw-rules.sh`](scripts/ufw-rules.sh) firewall, deny by default, explicit allows only
- [`scripts/healthcheck.sh`](scripts/healthcheck.sh) one command that answers "is it all still fine"

Every script has its install instructions in a comment header. Read them before running, they run as root and touch your firewall.

The README is the sequence and the reasoning. These four files are the parts that live on the server and keep working after you walk away. You need both.

## The pieces that matter

**Back up without disconnecting anyone.** Do not `cp` a live `.sqlitedb` file, you can get a torn copy. Use `sqlite3 .backup`, which takes a consistent snapshot while the server keeps running. That is what [`ts3-backup.sh`](scripts/ts3-backup.sh) does, on a nightly cron, keeping 7 days and deleting only files matching its own `auto-*` naming so your manual backups survive.

A backup that only exists on the server is not a backup. Pull them off the box periodically.

**Keep ServerQuery off the internet.** Bind it to `127.0.0.1` and reach it over an SSH tunnel when you need YaTQA or a bot:

```
ssh -L 10011:127.0.0.1:10011 -N root@YOUR_SERVER_IP
```

Then point YaTQA at `127.0.0.1:10011`. Note what [`ufw-rules.sh`](scripts/ufw-rules.sh) does not open: 10011 and 10022.

Put the admin password in a `chmod 600` `ts3server.ini` rather than on the command line, where anyone with shell access can read it out of `ps`.

**Patch automatically, but only security updates.** `unattended-upgrades` restricted to the `-security` pocket, with a conditional reboot window for the nights a kernel patch needs one. It will never touch your TeamSpeak install, because TeamSpeak is a tarball and apt does not know it exists. Upgrading TeamSpeak stays a manual job, and its database schema migrates forward only, so back up first, every time.

**Run fail2ban if SSH accepts passwords.** On a public VPS, port 22 gets thousands of brute force attempts a day. Four failures in ten minutes, banned for twenty four hours, is a sane starting point.

## Requirements

- A VPS with 1 vCPU and 1 GB RAM. That is genuinely enough. An instance running 5 virtual servers with 140 channels and 1,500 stored identities has a database of about 5 MB and barely touches the CPU.
- Ubuntu 22.04 LTS. Newer works, but 22.04 is more forgiving if you also want to run older 32-bit game binaries or legacy bots on the same box.
- `sqlite3` from apt, for the backup script.

## A note on the TeamSpeak server itself

The server binary is not in this repo and cannot be. TeamSpeak's licence does not allow redistributing it, so you download it from TeamSpeak's own servers, same as every other installer does.

If you are running for a community rather than commercially, look at the Non-Profit Licence. It lifts you from 32 slots to 512 and from 1 virtual server to 10, it is free, and it is a form you fill in. It expires annually, so put the renewal date in your own calendar the day you get it. Nothing warns you.

## Gotchas that cost me hours

- The server group named "Server Admin" is a **template**, not a real group. It cannot take members. Find the actual per-virtual-server admin group instead.
- Recent releases ship without updating the `CHANGELOG`, so the file lies about which version you are running. Check the version line in the startup log instead.
- If the server exits at startup with an instance check error, `tmpfs` is not mounted at `/dev/shm`. TeamSpeak uses shared memory to detect other running instances.

## Roadmap

Longer form docs are coming: a full provisioning walkthrough, the security setup in detail, and a proper gotchas list. The scripts above are the working parts and they are complete.

## Licence

MIT. See [LICENSE](LICENSE).

## Contributing

If your ISP routes some provider's blocks badly, open an issue with the numbers. A table of real measured latencies from real consumer connections would help people more than anything else in this repo.
