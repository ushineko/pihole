# Pi-hole Docker Setup

This project provides a Docker-based setup for [Pi-hole](https://pi-hole.net/), a network-wide ad blocker that can be used as a DNS server.

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Makefile Usage](#makefile-usage)
- [Configuration](#configuration)
  - [Core Settings](#core-settings-pi-hole-v6)
  - [VPN DNS Forwarding](#vpn-dns-forwarding)
  - [Host DNS Configuration](#host-dns-configuration-cachyossystemd-resolved)
- [Testing](#testing)
- [Management Commands](#management-commands)
- [Directory Structure](#directory-structure)
- [Security Notes](#security-notes)
- [License](#license)

## Features

- Network-wide ad blocking
- DNS server functionality
- Web interface for management
- Custom DNS configuration via `setup.sh`
- VPN DNS forwarding (route specific domains through VPN)
- Reverse DNS / conditional forwarding for local hostnames
- Persistent storage for settings
- Accessible from any device on the network

> **Note**: VPN forwarding and reverse DNS features have only been tested on CachyOS. They may work on other distributions depending on your network and VPN setup. YMMV.

## Prerequisites

- Docker
- Docker Compose
- Port 53 available (for DNS)
- Port 18080 available (for web interface)

## Quick Start

1. Clone this repository:
```bash
git clone <your-repo-url>
cd pihole
```

2. Configure environment:
```bash
cp .env.example .env
# Edit .env with your ROUTER_IP and optionally VPN_DNS_SERVER
```

3. Run setup and start:
```bash
make start
```

4. Access the web interface:
- URL: `http://<PIHOLE_HOST_IP>:18080/admin`
- Password: `admin` (set via `ADMIN_PASSWORD` in `.env`)

## Makefile Usage

The project includes a Makefile for easy container management. To see all available commands:

```bash
make help
```

Common commands:

```bash
make start    # Start Pi-hole
make stop     # Stop Pi-hole
make update   # Update to latest version and restart
make status   # Check container status
make logs     # View container logs
make shell    # Access container shell
make test     # Verify DNS resolution and ad blocking
make flush    # Clear dashboard history (flush logs)
```

The Makefile provides the following targets:

- **Main Commands**
  - `start`: Start the Pi-hole container
  - `stop`: Stop the Pi-hole container
  - `update`: Update and restart the Pi-hole container

- **Info Commands**
  - `status`: Show Pi-hole container status
  - `logs`: Show Pi-hole container logs
  - `shell`: Access Pi-hole container shell
  - `test`: Verify DNS resolution and ad blocking functionality
  - `flush`: Flush Pi-hole logs and clear dashboard history
  - `verify-wildcards`: Check that wildcard denies kept both regex anchors

- **Wildcard Commands**
  - `import-wildcards`: Apply `wildcards.list` (idempotent; verifies afterwards)
  - `fix-wildcards`: Repair wildcard denies that lost a regex anchor

## Wildcard Denies

Gravity matches **exact domains only**. A blocklist entry for `inmobi.com`
does not cover `cmp.inmobi.com`, so ad and tracker subdomains connect while
their parent is denied. Wildcard (regex) denies close that gap for a whole
label.

`wildcards.list` is the durable record — `etc-pihole/` is gitignored, so
`gravity.db` does not survive a container rebuild:

```bash
make import-wildcards   # reads wildcards.list, idempotent, self-verifying
```

Apply it on **every** resolver; the wildcards are per-instance.

### The anchoring trap

`pihole --wild` must be given **one domain per invocation**. Passing several in
a single argument silently stores broken fragments rather than erroring:

```bash
# WRONG - one argument, several domains
$ pihole --wild "a.example b.example"
    - (\.|^)a\.example      # lost its $ anchor
    - b\.example$            # lost its (\.|^) prefix
```

`CreateDomainList()` in `/opt/pihole/list.sh` wraps the whole argument once,
and `AddDomain()` then splits that string on spaces when building the API
payload — so the anchoring happens before the split and each fragment loses an
anchor. The fragments are valid regexes, so Pi-hole accepts them, but they
match as substrings: `a\.example` blackholes `a.example.attacker.net`, and
`b\.example$` blackholes `nota.example`. The failure direction is
**over-blocking**.

This is unchanged on Pi-hole `master` as of 2026-10-28 (identical to Core
v6.4), so updating the image does not fix it. `make import-wildcards` loops one
domain per call and cannot trigger it; `make verify-wildcards` runs after every
import so that a future caller which gets it wrong is caught rather than
silently over-blocking:

```bash
make verify-wildcards            # exits 1 and lists any unanchored entries
make fix-wildcards               # repairs them in place and reloads FTL

# Secondary resolver (separate host):
scp scripts/check-wildcard-anchoring.sh cachyos:/tmp/ && ssh cachyos /tmp/check-wildcard-anchoring.sh
```

The check only judges entries whose body is a plain escaped domain, so
hand-written regexes are left alone.

> After editing `domainlist` directly via sqlite, `pihole reloaddns` is **not**
> sufficient — it reloads the regex set but already-answered names keep their
> previous verdict, making a repair look like it failed. The script uses
> `pihole restartdns reload-lists` plus a cache flush.

## Configuration

### Core Settings (Pi-hole v6)
Pi-hole v6 uses `FTLCONF_` prefixed environment variables in `docker-compose.yml`. These are driven by the `.env` file for portability.

1.  **Configure Environment**:
    Copy `.env.example` to `.env` and update for your network:
    ```bash
    cp .env.example .env
    # Edit .env with your local ROUTER_IP
    # PIHOLE_HOST_IP is automatically detected by setup
    ```

2.  **Run Setup**:
    ```bash
    make setup
    ```

- **Upstream DNS**: `FTLCONF_dns_upstreams: [ "8.8.8.8", "8.8.4.4" ]` (set in `pihole.toml`)
- **Admin Password**: set via `ADMIN_PASSWORD` in `.env`.
- **Listening Mode**: `FTLCONF_dns_listeningMode: 'all'`
- **Web UI**: `http://<PIHOLE_HOST_IP>:18080/admin`

### VPN DNS Forwarding

Route specific domains through your VPN's DNS server (e.g., for accessing internal resources).

1. Edit `.env` and set your VPN DNS:
   ```bash
   VPN_DNS_SERVER=100.96.1.81
   VPN_DOMAINS=internal.company.com,vpn.example.net
   ```

2. Re-run setup and restart:
   ```bash
   make setup
   docker compose restart pihole
   ```

This generates `etc-dnsmasq.d/03-vpn-forwarding.conf` with conditional forwarding rules.

**Behavior when VPN is down**: Queries to these domains will return SERVFAIL (no fallback to public DNS). This is expected for internal-only resources.

### Host DNS Configuration (CachyOS/systemd-resolved)

**Port 53 Conflict Resolution**: By default, `systemd-resolved` listens on port 53, preventing the Pi-hole container from starting.

To configure your local system (running systemd-resolved, e.g., CachyOS/Arch/Ubuntu) to use this Pi-hole container for DNS, follow these steps:

1.  **Edit `/etc/systemd/resolved.conf`**:
    Open the configuration file with a text editor (`sudo vim /etc/systemd/resolved.conf`) and set the following parameters under the `[Resolve]` section:

    ```ini
    [Resolve]
    # Set Pi-hole (localhost) as primary, Google (8.8.8.8) as fallback
    DNS=127.0.0.1 8.8.8.8
    # Force systemd-resolved to prioritize global DNS settings
    Domains=~.
    # Disable the stub listener to free up port 53 for Pi-hole
    DNSStubListener=no
    ```

2.  **Restart systemd-resolved**:
    ```bash
    sudo systemctl restart systemd-resolved
    ```

3.  **Ensure Symlink Correctness**:
    Make sure `/etc/resolv.conf` is using the uplink mode (handled by `systemd-resolved`):
    ```bash
    sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    ```

    *Why?* This ensures that host applications use the DNS servers configured in `systemd-resolved` rather than just the local stub resolver (which we disabled).

### Custom dnsmasq Configuration
Additional dnsmasq settings can be added by creating files in `etc-dnsmasq.d/`. The setup script generates:
- `02-custom.conf` - Reverse DNS / conditional forwarding for local hostnames
- `03-vpn-forwarding.conf` - VPN domain forwarding (if configured)

## Testing

To test if the DNS server is working, use the `dig` command:
```bash
dig @localhost example.com
```

Or from another machine on the network:
```bash
dig @<your-host-ip> example.com
```

## Image Updates and Rollback

`image:` is `pihole/pihole:latest`, so `make update` moves to whatever `latest`
points at and the previous version is only recoverable if its digest was
recorded first. Capture it **before** pulling:

```bash
docker image inspect pihole/pihole:latest --format '{{index .RepoDigests 0}}'
```

To roll back, pin that digest in `docker-compose.yml` and `docker compose up -d`.
`./etc-pihole` is a host mount, so `gravity.db` (including wildcard denies and
adlists) survives a recreate in either direction.

| Date | From | To | Previous digest (rollback target) |
|---|---|---|---|
| 2026-10-28 | Core v6.4 / Web v6.4.1 / FTL v6.5 | Core v6.5 / Web v6.6.1 / FTL v6.8 | `sha256:ee348529cea9601df86ad94d62a39cad26117e1eac9e82d8876aa0ec7fe1ba27` |

### After upgrading, run gravity once

A v6.4-built `gravity.db` has the `antigravity` table (schema v21) but no
`antigravity_count` row in `info`, which FTL v6.8 queries — it logs
`gravityDB_count(... 'antigravity_count') - SQL error step no more rows
available` every ~26s until the counter exists. `make gravity` reseeds it (and
corrects a stale `gravity_count`). Regex denies live in `domainlist` and are
untouched by the rebuild.

## Management Commands

- View logs:
```bash
docker compose logs -f pihole
```

- Access container shell:
```bash
docker compose exec pihole bash
```

- Restart Pi-hole:
```bash
docker compose restart pihole
```

- Reset Web Interface Password:
```bash
docker compose exec pihole pihole -a -p <new_password>
```

## Directory Structure

- `etc-pihole/`: Persistent storage for Pi-hole configuration
- `etc-dnsmasq.d/`: Custom dnsmasq configuration
- `docker-compose.yml`: Container configuration using the official Pi-hole image

### Verification Tools
- `make status`: Quick check of container health.
- `make test`: Automated end-to-end check of DNS and Web UI.
- `make flush`: Clears long-term query database and logs (useful for fresh testing).

## Security Notes

- The default password is set to 'admin'. Change this after first login.
- The setup allows DNS queries from all networks by default.
- Consider restricting access based on your security requirements.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 