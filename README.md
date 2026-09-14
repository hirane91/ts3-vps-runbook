# ts3-vps-runbook

Running a TeamSpeak 3 server on a cheap VPS, written down properly.

There are plenty of one-command TeamSpeak installers on GitHub already. They work. What they don't tell you is which VPS to put it on, how to back up the database without kicking everyone off, how to patch the box without it silently breaking, or how to lock down ServerQuery so your admin password isn't sitting in `ps` output.

That's what this is. Less an installer, more a runbook. It came out of migrating a community server that had been running unattended for years and was quietly broken in four different ways.

## Who this is for

You want to host voice comms for a gaming community or a small org, you have shell access to a $5 to $10 VPS, and you'd rather set it up once and not think about it again.

You do not need to be a sysadmin. You do need to be comfortable pasting commands into SSH and reading the output.

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

```
scripts/
  ts3server.service   systemd unit, runs TeamSpeak as an unprivileged user
  ts3-backup.sh       nightly hot backup of the SQLite database, 7 day rotation
  ufw-rules.sh        firewall, deny by default, explicit allows only
  healthcheck.sh      one command that answers "is it all still fine"
```

Every script has its install instructions in a comment header. Read them before running, they run as root and touch your firewall.

## The pieces that matter

**Back up without disconnecting anyone.** Do not `cp` a live `.sqlitedb` file, you can get a torn copy. Use `sqlite3 .backup`, which takes a consistent snapshot while the server keeps running. That is what `ts3-backup.sh` does, on a nightly cron, keeping 7 days and deleting only files matching its own `auto-*` naming so your manual backups survive.

A backup that only exists on the server is not a backup. Pull them off the box periodically.

**Keep ServerQuery off the internet.** Bind it to `127.0.0.1` and reach it over an SSH tunnel when you need YaTQA or a bot:

```
ssh -L 10011:127.0.0.1:10011 -N root@YOUR_SERVER_IP
```

Then point YaTQA at `127.0.0.1:10011`. Note what `ufw-rules.sh` does not open: 10011 and 10022.

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
