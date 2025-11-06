FROM python:3.11-slim-bookworm

LABEL maintainer="youngs@suhlabs.com"
LABEL description="Proxmox Autoscaler for k3s clusters"

WORKDIR /app

# Install dependencies
COPY monitoring/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy autoscaler script
COPY monitoring/autoscaler.py .

# Run as non-root
RUN useradd -m -u 1000 autoscaler && \
    chown -R autoscaler:autoscaler /app

USER autoscaler

ENTRYPOINT ["python3", "autoscaler.py"]
