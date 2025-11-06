# Terraform backend configuration for Proxmox
# Configure HTTP backend (can use Vault, Consul, or custom endpoint)

# Example: Vault backend
address = "https://vault.corp.example.com/v1/secret/data/terraform/aiops/proxmox"
lock_address = "https://vault.corp.example.com/v1/secret/data/terraform/aiops/proxmox-lock"
unlock_address = "https://vault.corp.example.com/v1/secret/data/terraform/aiops/proxmox-lock"
username = "terraform"
