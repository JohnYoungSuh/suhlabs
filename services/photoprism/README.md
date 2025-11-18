# PhotoPrism - Family Photo Management Service

**Version**: 1.0.0
**License**: AGPL v3 (Free for personal/family use)

AI-powered photo management with facial recognition, automatic tagging, and family sharing.

## Features

- 📸 **Smart Organization**: AI-powered face detection and object recognition
- 🔍 **Powerful Search**: Find photos by people, places, things
- 🌍 **World Map**: View photos by location with interactive maps
- 👨‍👩‍👧‍👦 **Family Sharing**: Secure sharing with extended family (invite-based)
- 🔒 **Privacy-First**: Self-hosted, no cloud dependency
- 🎨 **Beautiful UI**: Modern web interface, mobile-friendly
- 🚀 **GPU Accelerated**: Fast ML processing with GPU support

## Architecture

```
photos.familyname.family (Ingress + TLS)
         │
    ┌────▼────┐
    │ Authelia│  ← LDAP/SSO Authentication
    │  (SSO)  │
    └────┬────┘
         │
    ┌────▼────────┐
    │ PhotoPrism  │
    │ Deployment  │  ← GPU-enabled for ML
    └─┬────────┬──┘
      │        │
 ┌────▼───┐  ┌▼──────┐
 │MariaDB │  │ MinIO │
 │(50GB)  │  │(3TB)  │
 └────────┘  └───────┘
```

## Quick Start

```bash
# Deploy full stack
cd services/photoprism
./deploy.sh

# Access
https://photos.familyname.family

# Default admin credentials (change immediately!)
Username: admin
Password: (stored in Vault: secret/photoprism/admin)
```

## Storage

- **Database**: MariaDB 10.11 (50GB)
- **Photos**: MinIO S3-compatible storage (3TB)
- **GPU**: Optional for ML features (face detection, object recognition)

## Requirements

- Kubernetes (K3s)
- MinIO (S3-compatible storage)
- cert-manager (TLS certificates)
- Vault (secrets management)
- Authelia (optional - SSO/LDAP)

## Documentation

- [Deployment Guide](./docs/DEPLOYMENT.md)
- [User Guide](./docs/USER-GUIDE.md)
- [Backup & Restore](./docs/BACKUP.md)
- [Troubleshooting](./docs/TROUBLESHOOTING.md)

## Integration with AI Ops Agent

```bash
# Via natural language
"Deploy PhotoPrism for my family"
"Import photos from /mnt/photos"
"Create sharing link for Grandma"
```

See `../../cluster/ai-ops-agent/config/intent-mappings.yaml` for details.

## License

PhotoPrism is licensed under AGPL v3. Free for personal and family use.
- **Free**: Personal, family, non-commercial
- **PhotoPrism Plus**: $30-60/year (optional commercial features)

See: https://www.photoprism.app/editions

---

Built with ❤️ for secure, private family photo management.
