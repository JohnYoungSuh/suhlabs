# Docker Desktop WSL2 Setup Guide

This guide helps you set up Docker Desktop with WSL2 integration for local development.

## Prerequisites

1. **Windows 10/11** with WSL2 enabled
2. **Docker Desktop for Windows** installed

## Quick Setup

### Step 1: Enable WSL2 Integration in Docker Desktop

1. Open **Docker Desktop**
2. Click the **Settings** gear icon (top right)
3. Go to **Resources → WSL Integration**
4. Enable:
   - ✅ **Enable integration with my default WSL distro**
   - ✅ Select your specific distro (e.g., **Ubuntu-22.04**)
5. Click **Apply & Restart**

### Step 2: Verify Docker in WSL2

Open WSL2 terminal:

```bash
# Check Docker is available
docker --version
# Should output: Docker version 24.x.x

# Check Docker Compose (V2 built-in)
docker compose version
# Should output: Docker Compose version v2.x.x

# Test Docker is running
docker ps
# Should show container list (might be empty)
```

### Step 3: Test with Project

```bash
cd /home/suhlabs/projects/suhlabs/aiops-substrate

# Pull latest changes
git pull origin claude/ansible-build-task-list-011CUsx6zna8cynVfXuZZ6Yt

# Start local stack
make vault-up
# Or full stack:
make dev-up
```

## Common Issues

### Issue 1: "docker: command not found"

**Cause**: Docker Desktop WSL2 integration not enabled

**Solution**:
1. Open Docker Desktop
2. Go to Settings → Resources → WSL Integration
3. Enable your distro
4. Restart Docker Desktop
5. Restart WSL2: `wsl --shutdown` (in PowerShell), then reopen WSL2

### Issue 2: "Cannot connect to the Docker daemon"

**Cause**: Docker Desktop is not running

**Solution**:
1. Start Docker Desktop (Windows Start menu)
2. Wait for it to fully start (whale icon in system tray)
3. Try again in WSL2

### Issue 3: "docker-compose: command not found"

**Cause**: Using old Docker Compose V1 syntax

**Solution**: The Makefile now uses `docker compose` (V2). If you still see this error:

```bash
# Check if Docker Compose V2 is available
docker compose version

# If not, update Docker Desktop to latest version
```

### Issue 4: Permission denied

**Cause**: User not in docker group (Linux-specific)

**Solution**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in, or:
newgrp docker
```

## Alternative: Install Docker in WSL2 Directly

If you prefer not to use Docker Desktop, you can install Docker directly in WSL2:

```bash
# Update package list
sudo apt update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Start Docker service
sudo service docker start

# Test
docker run hello-world
```

**Note**: This approach requires starting Docker manually or setting up systemd in WSL2.

## Verify Complete Setup

Run this checklist:

```bash
# 1. Docker installed
docker --version
# ✅ Should show version 24.x or higher

# 2. Docker Compose V2
docker compose version
# ✅ Should show v2.x or higher

# 3. Docker daemon running
docker ps
# ✅ Should show container list (no errors)

# 4. Can pull images
docker pull hello-world
# ✅ Should download successfully

# 5. Can run containers
docker run hello-world
# ✅ Should print "Hello from Docker!"

# 6. Makefile commands work
cd /home/suhlabs/projects/suhlabs/aiops-substrate
make vault-up
# ✅ Should start Vault container
```

## Next Steps

Once Docker is working:

1. Pull latest code: `git pull`
2. Start services: `make dev-up`
3. Create kind cluster: `make kind-up`
4. Continue with local development guide

See [local-development.md](local-development.md) for complete workflow.

## Resources

- [Docker Desktop WSL2 Backend](https://docs.docker.com/desktop/wsl/)
- [Install Docker in WSL2](https://docs.docker.com/engine/install/ubuntu/)
- [Docker Compose V2](https://docs.docker.com/compose/cli-command/)
