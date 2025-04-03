# Pi-hole Docker Setup

This project provides a Docker-based setup for [Pi-hole](https://pi-hole.net/), a network-wide ad blocker that can be used as a DNS server.

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
- Password: `admin`

## Configuration

### DNS Settings
- Default upstream DNS: 8.8.8.8 (Google DNS)
- Web interface port: 18080
- DNS port: 53 (TCP/UDP)

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
- `docker-compose.yml`: Container configuration
- `Dockerfile`: Image build configuration

## Security Notes

- The default password is set to 'admin'. Change this after first login.
- The setup allows DNS queries from all networks by default.
- Consider restricting access based on your security requirements.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 