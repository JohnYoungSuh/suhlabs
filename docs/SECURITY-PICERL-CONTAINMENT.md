# SECURITY-PICERL-CONTAINMENT: Isolation & Access Control

**Document Type:** Security - PICERL Phase: Containment  
**Version:** 1.0 | **Last Updated:** 2025-12-16

---

## 📊 At-a-Glance

**Purpose:** Limit blast radius of security incidents through network isolation and access controls.

**Defense Layers:**

1. **Network:** Linkerd mTLS + Network Policies (default deny)
2. **Access:** Vault RBAC + Kubernetes RBAC
3. **Segmentation:** VLAN isolation (IoT, Cameras, Management)

---

## 📖 Procedures

### Emergency Isolation

**If breach suspected:**

```bash
# 1. Isolate affected namespace
kubectl label namespace homeassistant isolation=quarantine

# 2. Apply deny-all network policy
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-emergency
  namespace: homeassistant
spec:
  pod Selector: {}
  policyTypes:
  - Ingress
  - Egress
EOF

# 3. Revoke Vault access
vault policy delete homeassistant-policy

# 4. Capture forensics
kubectl exec -n homeassistant deployment/homeassistant -- \
  tar czf /tmp/forensics.tar.gz /config /logs
```

---

**Document Status:** ✅ Complete - See SECURITY-PICERL-PREPARATION for network policies
