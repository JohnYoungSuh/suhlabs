# ============================================================================
# Variables for Local Kind Cluster Configuration
# ============================================================================

variable "cluster_name" {
  description = "Name of the Kind cluster"
  type        = string
  default     = "aiops-dev"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.cluster_name))
    error_message = "Cluster name must consist of lowercase alphanumeric characters or '-', and must start and end with an alphanumeric character."
  }
}

variable "worker_nodes" {
  description = "Number of worker nodes in the cluster"
  type        = number
  default     = 2

  validation {
    condition     = var.worker_nodes >= 1 && var.worker_nodes <= 10
    error_message = "Worker nodes must be between 1 and 10."
  }
}

variable "http_port" {
  description = "HTTP port to expose on the host"
  type        = number
  default     = 30080
}

variable "https_port" {
  description = "HTTPS port to expose on the host"
  type        = number
  default     = 30443
}

variable "environment" {
  description = "Environment name (development, staging, production)"
  type        = string
  default     = "development"

  validation {
    condition     = contains(["development", "staging", "production"], var.environment)
    error_message = "Environment must be one of: development, staging, production."
  }
}

variable "enable_network_policies" {
  description = "Whether to enable default-deny network policies for namespaces"
  type        = bool
  default     = false
}

variable "enable_resource_quotas" {
  description = "Whether to enable resource quotas for namespaces"
  type        = bool
  default     = false
}

variable "ai_ops_config" {
  description = "Configuration for AI Ops Agent"
  type = object({
    log_level   = optional(string, "info")
    ollama_host = optional(string, "http://ollama:11434")
    qdrant_host = optional(string, "http://qdrant:6333")
    vault_addr  = optional(string, "http://vault.vault.svc:8200")
  })
  default = {}
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    project    = "suhlabs"
    component  = "aiops-substrate"
    managed-by = "terraform"
  }
}
