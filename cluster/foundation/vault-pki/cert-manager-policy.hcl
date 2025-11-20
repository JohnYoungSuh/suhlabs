# Policy for cert-manager to issue certificates

# Allow cert-manager to request certificates
path "pki_int/issue/cert-manager" {
  capabilities = ["create", "update"]
}

# Allow cert-manager to request certificates for ai-ops-agent role
path "pki_int/issue/ai-ops-agent" {
  capabilities = ["create", "update"]
}

# Allow cert-manager to request certificates for kubernetes role
path "pki_int/issue/kubernetes" {
  capabilities = ["create", "update"]
}

# Allow cert-manager to read CA certificate
path "pki_int/ca" {
  capabilities = ["read"]
}

# Allow cert-manager to read CRL
path "pki_int/crl" {
  capabilities = ["read"]
}

# Allow cert-manager to sign CSRs
path "pki_int/sign/cert-manager" {
  capabilities = ["create", "update"]
}

path "pki_int/sign/ai-ops-agent" {
  capabilities = ["create", "update"]
}

path "pki_int/sign/kubernetes" {
  capabilities = ["create", "update"]
}
