# PhotoPrism Quick Start

Get PhotoPrism running in 5 minutes!

## Prerequisites

- K3s cluster running
- kubectl configured
- Domain name ready (e.g., photos.familyname.family)

## Deploy

```bash
cd services/photoprism
./deploy.sh
```

Wait ~10 minutes for all services to start.

## Configure DNS

Add DNS A record:
```
photos.familyname.family  →  <your-k3s-ingress-ip>
```

Get ingress IP:
```bash
kubectl get svc -n ingress-nginx
```

## Access

1. Go to: https://photos.familyname.family
2. Login:
   - Username: `admin`
   - Password: (check secret or default: `changeme`)
3. **Change password immediately!** (Settings → Account)

## Upload Photos

1. Click "Upload" button (top right)
2. Select photos from your computer
3. Wait for indexing to complete
4. Browse Library

## Share with Family

1. Settings → Users → Add User
2. Enter email and temporary password
3. User receives invitation email
4. Set permissions (Viewer, Contributor, Admin)

## Enable AI Features

PhotoPrism automatically:
- Detects faces
- Recognizes objects
- Reads GPS location
- Extracts metadata

Search by:
- `person:john` - Find photos of John
- `label:dog` - Find photos with dogs
- `color:blue` - Find blue-ish photos
- `location:paris` - Find photos in Paris

## Backup

```bash
# Quick backup script
./backup.sh
```

See [BACKUP.md](./BACKUP.md) for details.

## Troubleshooting

**Can't access**:
- Check DNS: `nslookup photos.familyname.family`
- Check pods: `kubectl get pods -n photoprism`
- Check TLS: `kubectl get certificate -n photoprism`

**Upload fails**:
- Check ingress max body size (default: 10GB)
- Check MinIO: `kubectl logs deployment/minio -n photoprism`

**Slow indexing**:
- Enable GPU (if available)
- Increase workers in Settings

## Next Steps

- Read [DEPLOYMENT.md](./DEPLOYMENT.md) for advanced configuration
- Set up Authelia for SSO [AUTH.md](./AUTH.md)
- Configure backups [BACKUP.md](./BACKUP.md)
- Invite family members

---

**Need help?** Check [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) or PhotoPrism docs at https://docs.photoprism.app/
