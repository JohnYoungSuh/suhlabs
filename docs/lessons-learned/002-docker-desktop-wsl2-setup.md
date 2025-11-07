# Lesson Learned: Docker Desktop vs Docker in WSL2

## Issue Date
2025-11-07

## Summary
New developers setting up WSL2 development environments often install Docker directly in WSL2 instead of using Docker Desktop with WSL2 integration, leading to configuration conflicts and confusion.

## The Common Mistake

### What Developers Do Wrong
```bash
# ❌ WRONG: Installing Docker Engine directly in WSL2
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo service docker start
```

This seems logical but creates problems:
- Conflicts with Docker Desktop
- Requires manual daemon management
- Service doesn't auto-start in WSL2
- Wastes system resources (two Docker engines)
- More complex troubleshooting

## Root Cause

### Why This Happens
1. **Background**: Developers used to Linux expect to install Docker like any other package
2. **WSL2 is different**: It's a Windows feature, not a standalone Linux system
3. **Docker Desktop exists**: Specifically designed for Windows + WSL2 integration
4. **Documentation confusion**: Multiple guides show different approaches

### The Confusion
```
Developer thinks:
"I'm in Linux (WSL2) → I should install Linux Docker"

Reality:
"WSL2 is a Windows feature → Use Windows Docker Desktop with WSL2 integration"
```

## Impact

- **Time wasted**: 30-60 minutes removing Docker from WSL2
- **Confusion**: "Why do I have two Dockers?"
- **Conflicts**: Commands work sometimes, fail other times
- **Resources**: Running duplicate Docker daemons

## The Correct Approach

### Architecture Overview

```
┌──────────────────────────────────────────────┐
│           Windows 11 Pro                     │
│                                              │
│  ┌────────────────────────────────────┐     │
│  │    Docker Desktop (Windows App)    │     │
│  │                                    │     │
│  │  ✅ ONE Docker daemon              │     │
│  │  ✅ Manages containers             │     │
│  │  ✅ GUI for management             │     │
│  │  ✅ Auto-starts with Windows       │     │
│  └────────────────────────────────────┘     │
│              ↓ WSL2 Integration             │
└──────────────────────────────────────────────┘
              ↓
┌──────────────────────────────────────────────┐
│           WSL2 (Ubuntu/Debian)               │
│                                              │
│  $ docker ps                                 │
│  $ docker-compose up                         │
│  $ docker build                              │
│     ↓                                        │
│  All commands talk to Docker Desktop         │
│  (No Docker daemon in WSL2)                  │
└──────────────────────────────────────────────┘
```

### Step-by-Step Setup

#### 1. Install Docker Desktop on Windows

Download from: https://www.docker.com/products/docker-desktop

- Install on **Windows** (not in WSL2)
- Accept default settings
- Restart if prompted

#### 2. Enable WSL2 Integration

Open Docker Desktop:

1. Click **Settings** (gear icon, top right)
2. Go to **Resources → WSL Integration**
3. Enable:
   - ✅ **"Enable integration with my default WSL distro"**
   - ✅ **Your specific distro** (Ubuntu, Ubuntu-22.04, etc.)
4. Click **"Apply & Restart"**

**Screenshot of setting location**:
```
Docker Desktop
└─ Settings (⚙️)
   └─ Resources
      └─ WSL Integration  ← Enable here
```

#### 3. Verify in WSL2

```bash
# Open WSL2 terminal

# Check Docker is accessible
docker --version
# Output: Docker version 28.x.x

# Verify it's Docker Desktop
docker info | grep "Operating System"
# Output: Operating System: Docker Desktop

# Check context
docker context ls
# Output: default * ... (using Docker Desktop)

# Test it works
docker run hello-world
# Output: Hello from Docker!
```

#### 4. If Docker Was Installed in WSL2, Remove It

```bash
# Stop Docker service (if running)
sudo systemctl stop docker
sudo systemctl disable docker

# Remove Docker packages
sudo apt remove docker docker-engine docker.io containerd runc
sudo apt autoremove

# Remove Docker data (optional - saves disk space)
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# Remove Docker group
sudo delgroup docker

# Restart WSL2
# In PowerShell (Windows):
wsl --shutdown
# Then reopen WSL2 terminal
```

## Verification Checklist

After setup, verify:

```bash
# ✅ 1. Docker command available
which docker
# Should show: /usr/bin/docker or /usr/local/bin/docker

# ✅ 2. Docker version matches Docker Desktop
docker --version
# Should show version 24.x or higher

# ✅ 3. Connected to Docker Desktop
docker info | grep -E "Operating System|Name"
# Should show:
#   Name: docker-desktop
#   Operating System: Docker Desktop

# ✅ 4. No local Docker daemon in WSL2
sudo systemctl status docker 2>&1 | grep "not be found"
# Should show: Unit docker.service could not be found

# ✅ 5. Docker Compose works (V2, built-in)
docker compose version
# Should show: Docker Compose version v2.x

# ✅ 6. Can run containers
docker run --rm alpine echo "Hello WSL2"
# Should output: Hello WSL2
```

## Troubleshooting

### Issue 1: "docker: command not found" in WSL2

**Cause**: WSL2 integration not enabled

**Fix**:
1. Open Docker Desktop
2. Settings → Resources → WSL Integration
3. Enable your distro
4. Apply & Restart
5. Restart WSL2: `wsl --shutdown` (in PowerShell), then reopen

### Issue 2: "Cannot connect to the Docker daemon"

**Cause**: Docker Desktop not running

**Fix**:
- Start Docker Desktop from Windows Start menu
- Wait for whale icon in system tray to become steady (not animated)

### Issue 3: WSL2 distro not showing in integration list

**Cause**: Distro not properly registered with WSL2

**Fix**:
```powershell
# In PowerShell (Windows)
wsl --list --verbose
# Check your distro shows VERSION 2

# If VERSION 1, upgrade to WSL2:
wsl --set-version Ubuntu 2
```

### Issue 4: Have both Docker Desktop and Docker in WSL2

**Cause**: Installed Docker directly in WSL2 before setting up Docker Desktop

**Fix**: Remove Docker from WSL2 (see step 4 above)

### Issue 5: "docker-compose: command not found"

**Cause**: Using old V1 syntax

**Fix**: Use V2 syntax (built into Docker Desktop)
```bash
# Old (V1):
docker-compose up

# New (V2):
docker compose up
```

## Key Takeaways for New Developers

1. **Windows + WSL2 = Use Docker Desktop**
   - Don't install Docker in WSL2
   - Use Docker Desktop with WSL2 integration

2. **One Docker daemon to rule them all**
   - Docker Desktop runs on Windows
   - WSL2 talks to it via integration
   - No need for duplicate installations

3. **Check first, install later**
   - Always verify Docker Desktop integration before installing anything
   - Run `docker info` to see what's already configured

4. **WSL2 ≠ Full Linux**
   - WSL2 is a Windows feature, not a VM
   - Follow Windows-specific guides for WSL2
   - Linux-only guides may not apply

5. **Modern Docker Compose is V2**
   - Command: `docker compose` (not `docker-compose`)
   - Built into Docker Desktop
   - No separate installation needed

## Comparison Table

| Aspect | Docker Desktop (✅ Recommended) | Docker in WSL2 (❌ Not Recommended) |
|--------|----------------------------------|-------------------------------------|
| Installation | Install on Windows | Install in WSL2 Linux |
| Management | GUI + CLI | CLI only |
| Auto-start | Starts with Windows | Requires `sudo service docker start` |
| WSL2 Support | Built-in integration | Manual configuration |
| Windows Integration | Full (GUI, volumes, networking) | Limited |
| Resource Usage | Single daemon | Duplicate daemon (waste) |
| Maintenance | Auto-updates | Manual updates |
| Support | Official Docker support | Community only |
| Best for | Windows + WSL2 development | Pure Linux environments |

## Documentation References

- [Docker Desktop WSL2 Backend](https://docs.docker.com/desktop/wsl/)
- [Install Docker Desktop on Windows](https://docs.docker.com/desktop/install/windows-install/)
- [WSL2 Best Practices](https://docs.microsoft.com/en-us/windows/wsl/compare-versions)

## Environment Details

- **OS**: Windows 11 Pro
- **WSL Version**: WSL2
- **Linux Distro**: Ubuntu 22.04 (or similar)
- **Docker Desktop**: 4.24.0+ (or latest)

## Testing in New Environment

When setting up a new machine:

```bash
# 1. Verify Docker Desktop is installed (Windows)
# Check: System tray should show Docker whale icon

# 2. Enable WSL2 integration
# Docker Desktop → Settings → Resources → WSL Integration

# 3. Test in WSL2
docker run hello-world

# 4. Test docker-compose (V2)
docker compose version
```

## Related Issues

- Docker Desktop WSL2 integration documentation
- WSL2 known issues with Docker
- Docker Compose V1 vs V2 migration

## Prevention

### For New Team Members

Add to onboarding checklist:

- [ ] Install Docker Desktop on Windows (not in WSL2)
- [ ] Enable WSL2 integration in Docker Desktop
- [ ] Verify `docker info` shows "Docker Desktop"
- [ ] Verify `docker compose version` shows V2
- [ ] **Do NOT install Docker in WSL2**

### For Documentation

Add prominent warning in setup guides:

> **⚠️ Important for Windows + WSL2 Users**
>
> Do NOT install Docker directly in WSL2. Instead:
> 1. Install Docker Desktop on Windows
> 2. Enable WSL2 integration in Docker Desktop settings
>
> See [Docker Desktop Setup Guide](#) for details.

---

**Author**: Infrastructure Team
**Reviewers**: DevOps Team
**Status**: Documented
**Environment**: Windows 11 Pro + WSL2 + Docker Desktop
**Related Tickets**: HOMELAB-3
**Lesson**: 002
