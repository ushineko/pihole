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