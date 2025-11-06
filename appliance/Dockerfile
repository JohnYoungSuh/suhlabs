FROM debian:bookworm-slim

# Install system packages for all services
RUN apt-get update && apt-get install -y \
    dnsmasq \
    samba \
    samba-common-bin \
    postfix \
    python3 \
    python3-pip \
    curl \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /opt/aiops /srv/shares /var/log/aiops

# Copy agent code
COPY agent/requirements.txt /opt/aiops/
RUN pip3 install --break-system-packages -r /opt/aiops/requirements.txt

COPY agent/ /opt/aiops/agent/
COPY services/ /opt/aiops/services/

# Setup supervisord to manage all services
COPY supervisor/supervisord.conf /etc/supervisor/conf.d/aiops.conf

# Expose ports
EXPOSE 53/udp 80 139 445

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
    CMD pgrep -f "python3.*agent.py" || exit 1

# Run supervisord to manage all services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
