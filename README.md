# ts3-vps-runbook

Running a TeamSpeak 3 server on a cheap VPS, written down properly.

There are plenty of one-command TeamSpeak installers on GitHub already. They work. What they don't tell you is which VPS to put it on, how to back up the database without kicking everyone off, how to patch the box without it silently breaking, or how to lock down ServerQuery so your admin password isn't sitting in `ps` output.

That's what this is. Less an installer, more a runbook. It came out of migrating a community server that had been running unattended for years and was quietly broken in four different ways.

## Who this is for

You want to host voice comms for a gaming community or a small org, you have shell access to a $5 to $10 VPS, and you'd rather set it up once and not think about it again.

You do not need to be a sysadmin. You do need to be comfortable pasting commands into SSH and reading the output.

## The one thing most guides get wrong

Pick the host by measuring latency, not by reading the datacentre location.

Two servers in the same building, same provider, can be 160 ms apart for your users, because providers own multiple IP blocks and your ISP routes them completely differently. On one migration, measured from a consumer connection in the UAE to Singapore:

| Provider IP block | Ping |
|---|---|
| Block A | 82 ms |
| Block B | 244 ms |
| Block C | 255 ms |

Same provider. Same city. Same datacentre. Three times the latency depending on which address you happen to get assigned.

Worse, the provider's own looking-glass and speedtest endpoints lie to you. They sit in different IP ranges from customer instances. One provider's test host answered in 81 ms while a real server of theirs in that same datacentre answered in 244 ms.

So: most VPS providers bill by the hour. Deploy a real instance, ping it from where your users actually are, and if the number is bad, destroy it and deploy again until you get an address in a block that routes well. It costs cents. Do this **before** you invest an evening in setup. See [docs/01-choosing-a-host.md](docs/01-choosing-a-host.md).

## What's in here

```
docs/
  01-choosing-a-host.md   latency-first selection, what to test and how
  02-provisioning.md      Ubuntu, users, swap, firewall
  03-teamspeak.md         install, systemd unit, licence file
  04-security.md          ServerQuery on localhost, SSH tunnel for YaTQA, fail2ban
  05-backups.md           hot SQLite backups, rotation, getting them off the box
  06-maintenance.md       security-only auto-patching, conditional reboots
  07-gotchas.md           the things that cost me hours
scripts/
  ts3server.service       systemd unit
  ts3-backup.sh           nightly hot backup, 7 day rotation
  ufw-rules.sh            firewall, explicit rules only
  healthcheck.sh          one command that answers "is it all still fine"
examples/
  ts3server.ini.example
```

## Quick path

Assuming a fresh Ubuntu 22.04 box you've already latency-tested:

```bash
git clone https://github.com/YOUR_USERNAME/ts3-vps-runbook.git
cd ts3-vps-runbook
# read this before running anything
less docs/02-provisioning.md
```

Nothing here is a magic `curl | bash`. The scripts are small enough to read in a minute and you should read them, because they run as root and touch your firewall.

## Requirements

- A VPS with 1 vCPU and 1 GB RAM. That is genuinely enough. A 5 virtual server instance with 140 channels and 1,500 stored identities uses a database of about 5 MB and barely touches the CPU.
- Ubuntu 22.04 LTS. Newer works, but 22.04 is more forgiving if you also want to run older 32-bit game binaries or legacy bots on the same box.
- `sqlite3` and `bzip2` from apt.

## A note on the TeamSpeak server itself

The server binary is not in this repo and can't be. TeamSpeak's licence doesn't allow redistributing it, so the install step downloads it from TeamSpeak's own servers, same as every other installer does.

If you're running for a community rather than commercially, look at the Non-Profit Licence. It lifts you from 32 slots to 512 and from 1 virtual server to 10, it's free, and it's a form you fill in. It expires annually, so put the renewal date in your calendar the day you get it. Nothing warns you.

## Licence

MIT. See [LICENSE](LICENSE).

## Contributing

If your ISP routes some provider's blocks badly, open an issue with the numbers. A table of real measured latencies from real consumer connections would be more useful to people than anything else in this repo.
