# Pi-hole Docker Setup

This project provides a Docker-based setup for [Pi-hole](https://pi-hole.net/), a network-wide ad blocker that can be used as a DNS server.

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Auto-start Configuration](#auto-start-configuration)
  - [NixOS](#nixos)
  - [Ubuntu/Debian](#ubuntudebian)
- [Makefile Usage](#makefile-usage)
- [Configuration](#configuration)
  - [DNS Settings](#dns-settings)
  - [Custom Configuration](#custom-configuration)
- [Testing](#testing)
- [Management Commands](#management-commands)
- [Directory Structure](#directory-structure)
- [Security Notes](#security-notes)
- [License](#license)

## Features

- Network-wide ad blocking
- DNS server functionality
- Web interface for management
- Custom DNS configuration
- Persistent storage for settings
- Accessible from any device on the network

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

2. Create the necessary configuration directories:
```bash
mkdir -p etc-pihole etc-dnsmasq.d
```

3. Create the dnsmasq configuration file:
```bash
cat > etc-dnsmasq.d/02-custom.conf << 'EOL'
# Allow all origins
all-servers
domain-needed
bogus-priv
no-resolv
no-poll
expand-hosts
cache-size=10000
domain=local
local=/
listen-address=0.0.0.0
bind-interfaces
rebind-localhost-ok
rebind-domain-ok=local
EOL
```

4. Start Pi-hole:
```bash
docker compose up -d
```

5. Access the web interface:
- URL: `http://localhost:18080/admin`
- Username: `admin`
- Password: `admin` (Default, set in `docker-compose.yml`)

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

## Auto-start Configuration

### NixOS

To make Pi-hole start automatically on boot in NixOS, add the following to your `configuration.nix`:

```nix
{ config, pkgs, ... }: {
  systemd.services.pihole = {
    description = "Pi-hole Docker Container";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/path/to/your/pihole/directory";
      ExecStart = "${pkgs.docker}/bin/docker compose up -d";
      ExecStop = "${pkgs.docker}/bin/docker compose down";
      TimeoutStartSec = 0;
    };
  };
}
```

Replace `/path/to/your/pihole/directory` with the actual path to your Pi-hole directory.

After adding this configuration:
1. Rebuild your NixOS configuration:
```bash
sudo nixos-rebuild switch
```

2. Verify the service is enabled:
```bash
systemctl status pihole
```

### Ubuntu/Debian

To make Pi-hole start automatically on boot in Ubuntu/Debian:

1. Create a systemd service file:
```bash
sudo nano /etc/systemd/system/pihole.service
```

2. Add the following content (replace the path with your actual Pi-hole directory):
```ini
[Unit]
Description=Pi-hole Docker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/path/to/your/pihole/directory
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

3. Enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable pihole
sudo systemctl start pihole
```

4. Verify the service is running:
```bash
sudo systemctl status pihole
```

## Configuration

### DNS Settings
- Default upstream DNS: 8.8.8.8 (Google DNS)
- Web interface port: 18080
- DNS port: 53 (TCP/UDP)

### Host DNS Configuration (CachyOS/systemd-resolved)

**Port 53 Conflict Resolution**: By default, `systemd-resolved` listens on port 53 (specifically `127.0.0.53:53`), which prevents the Pi-hole container from binding to host port 53. To allow Pi-hole to run, we must disable this stub listener.

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

### Custom Configuration
The setup includes custom dnsmasq configuration to allow queries from all networks. This can be modified in `etc-dnsmasq.d/02-custom.conf`.

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

## Directory Structure

- `etc-pihole/`: Persistent storage for Pi-hole configuration
- `etc-dnsmasq.d/`: Custom dnsmasq configuration
- `docker-compose.yml`: Container configuration using the official Pi-hole image

## Security Notes

- The default password is set to 'admin'. Change this after first login.
- The setup allows DNS queries from all networks by default.
- Consider restricting access based on your security requirements.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 