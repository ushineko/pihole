#!/bin/bash

# Wait for Pi-hole to be ready
sleep 5

# Set the password
pihole -a -p admin

# Keep the container running
tail -f /dev/null 