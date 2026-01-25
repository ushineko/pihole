#!/bin/bash
set -e

# Pi-hole First-Time Setup Script
# Documented and persistent configuration for Pi-hole v6

# Source environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "ERROR: .env file not found. Copy .env.example to .env and configure it."
    exit 1
fi

echo "--- Configuring Pi-hole Directories ---"
mkdir -p etc-pihole etc-dnsmasq.d

echo "--- Configuring Reverse DNS (Conditional Forwarding) ---"
# This ensures local hostnames are resolved by the router
sudo tee etc-dnsmasq.d/02-custom.conf <<EOF > /dev/null
# Custom dnsmasq settings for Pi-hole
# Managed by Antigravity - Optimized for v6 Hostnames

# Allow all origins (v6 handle this via FTLCONF, but dnsmasq layer safe-keep)
all-servers

# Local Network Settings
domain=lan
expand-hosts

# Conditional Forwarding (Router: $ROUTER_IP, Network: $LOCAL_NETWORK)
server=/lan/$ROUTER_IP
server=/$REV_SERVER_DOMAIN/$ROUTER_IP
EOF

echo "--- Configuring Admin Credentials ---"
# The admin password is primarily driven by FTLCONF_webserver_api_password in docker-compose.yml.
# We ensure the directories are ready for FTL to write its persistent state.
if [ ! -f etc-pihole/pihole.toml ]; then
    echo "[setup] Initializing minimal pihole.toml..."
    sudo tee etc-pihole/pihole.toml <<EOF > /dev/null
[dns]
upstreams = ["8.8.8.8", "8.8.4.4"]
domain.name = "lan"
listeningMode = "all"
bogusPriv = false
domainNeeded = true

[misc]
etc_dnsmasq_d = true

[webserver]
api.password = "$ADMIN_PASSWORD"
EOF
fi

echo "--- Setup Complete ---"
echo "You can now run 'make update' to apply the configuration and start Pi-hole."
