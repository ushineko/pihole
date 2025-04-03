FROM pihole/pihole:latest

# Expose ports for DNS (53) and web interface (80)
EXPOSE 53/tcp 53/udp 80/tcp

# Set environment variables
ENV TZ=UTC

# Add custom DNS servers (optional)
ENV DNS1=1.1.1.1
ENV DNS2=1.0.0.1

# Create necessary directories
RUN mkdir -p /etc/pihole /etc/dnsmasq.d

# Copy custom configurations if needed
COPY ./custom.list /etc/pihole/custom.list
COPY ./custom.conf /etc/dnsmasq.d/custom.conf

# Copy and set up entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost/admin/ || exit 1

# Use our custom entrypoint
ENTRYPOINT ["/entrypoint.sh"] 