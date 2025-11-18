# PhotoPrism Family Onboarding Guide

Complete guide to onboarding new families to PhotoPrism using the conversational AI Ops bot.

---

## Overview

The PhotoPrism onboarding system provides a **fully automated, conversational** process for deploying PhotoPrism instances for new families. The AI Ops/Sec bot guides families through:

1. **Family Name Collection** - IT ops identifier (e.g., `smith`)
2. **Domain Availability Check** - Automatically checks `.family` domain availability
3. **Alternative Suggestions** - Suggests available alternatives if first choice is taken
4. **Domain Registration** - Automatically registers chosen domain
5. **Contact Information** - Collects admin email for notifications
6. **Automated Deployment** - Deploys PhotoPrism with family-specific configuration
7. **DNS Configuration** - Sets up A records for the domain
8. **Credential Delivery** - Provides secure admin credentials

---

## For Families (Customer-Facing)

### Starting Onboarding

To get started with PhotoPrism for your family, talk to the AI Ops bot:

**Example conversation:**

```
You: "I want to set up PhotoPrism for my family"

AI Ops Bot: 👋 Welcome to PhotoPrism Family Setup!

I'll help you set up your own private family photo library with AI-powered
features like face recognition, automatic organization, and smart search.

This will take about 15 minutes. Let's get started!

What's your family name? (e.g., "Smith", "Johnson", "García")

You: Smith

AI Ops Bot: 📋 Great! Let me check if smith.family is available as your domain...

✅ Good news! The domain smith.family is available!

Your PhotoPrism will be accessible at:
🌐 https://photos.smith.family

Is this OK? (yes/no, or suggest a different name)

You: yes

AI Ops Bot: 📧 Perfect! I need an email address for:
- Admin account notifications
- Password reset emails
- Storage alerts

What email should I use?

You: admin@smith.family

AI Ops Bot: 🚀 Excellent! I'm now setting up PhotoPrism for The Smith Family.

**What I'm doing:**
1. Registering smith.family domain ✓
2. Configuring DNS records ⏳
3. Deploying PhotoPrism services ⏳
4. Setting up secure storage ⏳
5. Creating TLS certificates ⏳

This will take about 10-15 minutes. I'll notify you when it's ready!

☕ Grab a coffee while I work...

---

🎉 Your PhotoPrism is ready!

**Access Information:**
📱 URL: https://photos.smith.family
👤 Username: admin@smith.family
🔑 Password: [secure password shown here]

**Important:**
⚠️ Save your password securely!
⚠️ Change it after first login (Settings → Account)

**What you can do now:**
1. Log in and explore the interface
2. Upload your first photos
3. Invite family members
4. Enable face recognition

Need help? Just ask me: "How do I upload photos?"
```

### Common Questions

**Q: What if my family name is taken?**
A: The AI Ops bot will automatically suggest alternatives like `smith-family`, `thesmiths`, `smithphotos`, etc.

**Q: Can I use a different domain extension?**
A: Currently, we use `.family` domains for all families. Custom domains coming soon!

**Q: How much does it cost?**
A: Domain registration: ~$20-30/year. Storage: Included in your plan (1TB default).

**Q: How long does onboarding take?**
A: About 15 minutes from start to finish. The bot will guide you through every step.

**Q: What if something goes wrong?**
A: The bot monitors deployment and will notify you of any issues. You can also ask: "Check my PhotoPrism status"

---

## For IT Ops (Admin-Facing)

### Onboarding Architecture

The onboarding system consists of:

1. **Conversational Flow** (`ai_ops_agent/onboarding/__init__.py`)
   - State machine with 8 steps
   - Session management
   - Input validation
   - Error handling

2. **Domain Management** (`ai_ops_agent/domain/__init__.py`)
   - Domain availability checking (Cloudflare, Namecheap, GoDaddy)
   - Alternative domain suggestions
   - Domain registration APIs
   - DNS configuration

3. **API Endpoints** (`main.py`)
   - `POST /api/v1/photoprism/onboard` - Start onboarding
   - `POST /api/v1/photoprism/onboard/{session_id}/respond` - Continue conversation
   - `GET /api/v1/photoprism/storage` - Check storage status

4. **Deployment Script** (`deploy-family.sh`)
   - Kustomize-based templating
   - Variable substitution
   - Vault secrets management
   - Health checks

5. **Kubernetes Templates** (`kustomize/base/`, `kustomize/overlays/`)
   - Multi-tenant namespace isolation
   - Per-family PVCs, secrets, configmaps
   - Family-specific ingress rules
   - Monitoring with family labels

### Onboarding Flow Diagram

```
┌──────────────────────────────────────────────────────────────┐
│ 1. WELCOME                                                   │
│    - Greet family                                            │
│    - Explain PhotoPrism features                             │
│    - Ask for family name                                     │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ↓ (user provides name)
┌──────────────────────────────────────────────────────────────┐
│ 2. COLLECT_FAMILY_NAME                                       │
│    - Normalize input (lowercase, alphanumeric)              │
│    - Store preferred_name (display name)                     │
│    - Store family_name (IT ops identifier)                   │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ↓
┌──────────────────────────────────────────────────────────────┐
│ 3. CHECK_DOMAIN                                              │
│    - Query domain registrar API                              │
│    - Check: family_name.family availability                  │
└────────────────────────┬─────────────────────────────────────┘
                         │
           ┌─────────────┴─────────────┐
           │ Available?                 │
           └─────────────┬─────────────┘
                         │
        ┌────────────────┼────────────────┐
        │ YES            │ NO              │
        ↓                ↓                 │
    Domain OK        SUGGEST_ALTERNATIVES │
                         │                 │
                         └─────────────────┘
                         │
                         ↓
┌──────────────────────────────────────────────────────────────┐
│ 4. CONFIRM_DOMAIN                                            │
│    - Show final domain: photos.family_name.family            │
│    - Confirm with user                                       │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ↓ (user confirms)
┌──────────────────────────────────────────────────────────────┐
│ 5. COLLECT_CONTACT                                           │
│    - Ask for admin email                                     │
│    - Validate email format                                   │
│    - Store contact_email                                     │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ↓
┌──────────────────────────────────────────────────────────────┐
│ 6. DEPLOYMENT_IN_PROGRESS                                    │
│    - Register domain (via registrar API)                     │
│    - Configure DNS A records                                 │
│    - Generate admin password (secure)                        │
│    - Execute: deploy-family.sh                               │
│    - Monitor deployment progress                             │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ↓ (15 minutes)
┌──────────────────────────────────────────────────────────────┐
│ 7. DEPLOYMENT_COMPLETE                                       │
│    - Verify all pods running                                 │
│    - Verify TLS certificate issued                           │
│    - Verify ingress accessible                               │
└────────────────────────┬─────────────────────────────────────┘
                         │
                         ↓
┌──────────────────────────────────────────────────────────────┐
│ 8. COMPLETED                                                 │
│    - Provide URL and credentials                             │
│    - Send welcome email                                      │
│    - Log successful onboarding                               │
└──────────────────────────────────────────────────────────────┘
```

### Variable Usage

Throughout the onboarding process, two primary identifiers are used:

| Variable | Purpose | Example | Used By |
|----------|---------|---------|---------|
| `$family_name` | IT ops identifier for infrastructure | `smith` | Kubernetes resources, DNS, Vault, metrics |
| `$preferred_name` | Customer-facing display name | `The Smith Family` | AI bot messages, UI, emails |

**Key Rules:**
- **AI Ops Bot** → Uses `$preferred_name` in all customer communications
- **All IT Systems** → Always use `$family_name` for namespacing and tagging
- **Infrastructure** → Everything tagged with `family: $family_name` label

See [FAMILY_NAME_VARIABLES.md](./FAMILY_NAME_VARIABLES.md) for complete mapping.

### API Usage

#### Start Onboarding

```bash
curl -X POST https://ai-ops.suhlabs.io/api/v1/photoprism/onboard \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "user123",
    "user_email": "john@example.com"
  }'
```

**Response:**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "👋 Welcome to PhotoPrism Family Setup!\n\nWhat's your family name?",
  "step": "WELCOME",
  "completed": false
}
```

#### Continue Conversation

```bash
curl -X POST https://ai-ops.suhlabs.io/api/v1/photoprism/onboard/550e8400-e29b-41d4-a716-446655440000/respond \
  -H "Content-Type: application/json" \
  -d '{
    "user_input": "Smith"
  }'
```

**Response:**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "📋 Let me check if smith.family is available...\n\n✅ Good news! smith.family is available!",
  "step": "CHECK_DOMAIN",
  "completed": false
}
```

#### Check Storage

```bash
curl -X GET "https://ai-ops.suhlabs.io/api/v1/photoprism/storage?family_name=smith"
```

**Response:**
```json
{
  "family_name": "smith",
  "namespace": "photoprism-smith",
  "storage": {
    "photos": {
      "used_bytes": 805306368000,
      "capacity_bytes": 1099511627776,
      "usage_percent": 73.2,
      "pvc_name": "minio-photos"
    }
  },
  "alerts": {
    "active": false,
    "warnings": [],
    "critical": []
  }
}
```

### Manual Deployment

If you need to deploy PhotoPrism manually (bypassing the AI bot):

```bash
# Navigate to PhotoPrism directory
cd services/photoprism

# Set environment variables
export FAMILY_NAME="smith"
export PREFERRED_NAME="The Smith Family"
export CONTACT_EMAIL="admin@smith.family"
export ENABLE_GPU="true"
export ENABLE_AUTHELIA="true"

# Run deployment script
./deploy-family.sh
```

The script will:
1. Validate requirements (kubectl, kustomize)
2. Generate family-specific Kustomize overlay
3. Build Kubernetes manifests with variable substitution
4. Apply to cluster
5. Wait for services to be ready
6. Configure Vault secrets
7. Display access information

### Monitoring Onboarding

#### Check deployment status

```bash
# Get all resources for a family
kubectl get all -n photoprism-smith

# Check pod logs
kubectl logs -f deployment/photoprism -n photoprism-smith

# Check TLS certificate
kubectl get certificate -n photoprism-smith
kubectl describe certificate photoprism-smith-tls -n photoprism-smith

# Check ingress
kubectl get ingress -n photoprism-smith
```

#### Prometheus Queries

```promql
# Storage usage for a family
(
  sum(kubelet_volume_stats_used_bytes{namespace="photoprism-smith",persistentvolumeclaim="minio-photos"})
  /
  sum(kubelet_volume_stats_capacity_bytes{namespace="photoprism-smith",persistentvolumeclaim="minio-photos"})
) * 100

# Service uptime
up{job="photoprism",namespace="photoprism-smith"}

# Memory usage
sum(container_memory_usage_bytes{namespace="photoprism-smith",pod=~"photoprism-.*"})
```

### Troubleshooting

#### Common Issues

**1. Domain not accessible after deployment**

Check DNS propagation:
```bash
dig photos.smith.family
nslookup photos.smith.family
```

Solution: DNS can take 5-60 minutes to propagate. Wait or use `/etc/hosts` for testing.

**2. TLS certificate not issued**

```bash
kubectl describe certificate photoprism-smith-tls -n photoprism-smith
kubectl logs -n cert-manager -l app=cert-manager
```

Solution: Verify cert-manager is running and Vault issuer is configured.

**3. PhotoPrism pod stuck in CrashLoopBackOff**

```bash
kubectl logs deployment/photoprism -n photoprism-smith
```

Common causes:
- MariaDB not ready → Wait longer
- S3 credentials invalid → Check MinIO secrets
- Insufficient resources → Check node capacity

**4. Storage alert triggering during initial sync**

```bash
# Check actual usage
kubectl exec -it deployment/photoprism -n photoprism-smith -- df -h
```

Solution: Initial thumbnail generation uses more cache. Alert should clear after indexing completes.

### Security Considerations

**Secrets Management:**
- All passwords stored in Vault: `secret/photoprism/$family_name/*`
- Auto-generated passwords (20 chars, mixed case + special)
- Secrets never logged or displayed except during onboarding

**Network Isolation:**
- Each family in separate namespace: `photoprism-$family_name`
- NetworkPolicies restrict inter-family communication
- Istio service mesh for mTLS (if enabled)

**Access Control:**
- RBAC policies limit access to namespace
- Authelia for SSO/MFA (optional)
- Admin credentials sent via secure channel only

**Audit Trail:**
- All onboarding events logged with family_name
- Deployment tracked in ML logs
- Storage alerts tagged with family for tracking

### Scaling Considerations

**Per-Family Resources:**
- Default: 2 PhotoPrism replicas (HA)
- CPU: 2 cores requested, 8 cores limit
- Memory: 4Gi requested, 16Gi limit
- Storage: 1Ti photos, 50Gi database, 100Gi cache

**Cluster Capacity:**
- Each family: ~2-4 cores, ~8-16Gi RAM, ~1.15Ti storage
- 10 families: ~20-40 cores, ~80-160Gi RAM, ~11.5Ti storage
- Scale workers accordingly

**Cost Estimates:**
- Domain: $20-30/year
- Storage (1TB): $10-40/month (depending on provider)
- Compute: Shared K3s infrastructure
- **Total per family:** ~$25-50/month

### Future Enhancements

- [ ] Automated domain renewal
- [ ] Custom domain support (bring your own domain)
- [ ] Billing integration (usage-based pricing)
- [ ] Self-service storage expansion
- [ ] Family member invitation workflow
- [ ] Backup/restore automation
- [ ] Migration from Google Photos/iCloud
- [ ] Mobile app integration
- [ ] Video transcoding optimization

---

## Testing the Onboarding Flow

### Local Testing

```bash
# 1. Start AI Ops agent
cd cluster/ai-ops-agent
uvicorn main:app --reload

# 2. In another terminal, start onboarding
curl -X POST http://localhost:8000/api/v1/photoprism/onboard \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test", "user_email": "test@example.com"}'

# 3. Extract session_id from response, then continue
SESSION_ID="<session-id-from-response>"

curl -X POST "http://localhost:8000/api/v1/photoprism/onboard/$SESSION_ID/respond" \
  -H "Content-Type: application/json" \
  -d '{"user_input": "TestFamily"}'

# 4. Follow prompts until deployment
```

### End-to-End Test

```bash
# Run full onboarding test
cd services/photoprism
./test-onboarding.sh testfamily
```

This script:
1. Initiates onboarding via API
2. Simulates user responses
3. Triggers deployment
4. Verifies all services running
5. Tests HTTP access
6. Cleans up test resources

---

## Support

**For Families:**
- Talk to AI Ops bot: "I need help with PhotoPrism"
- Email: support@suhlabs.io
- Documentation: [User Guide](./USER_GUIDE.md)

**For IT Ops:**
- Internal docs: `/docs/photoprism/`
- Runbook: [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- Metrics: Grafana dashboard "PhotoPrism Multi-Tenant"

---

**Onboarding Checklist:**
- ✅ Domain available and registered
- ✅ DNS A records configured
- ✅ Kubernetes resources deployed
- ✅ TLS certificate issued
- ✅ Services accessible via HTTPS
- ✅ Admin credentials delivered
- ✅ Storage monitoring active
- ✅ Welcome email sent
