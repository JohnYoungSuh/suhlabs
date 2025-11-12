# ============================================================================
# Terraform Configuration for Local Kind Cluster
# Day 3: IaC Muscle Memory
# ============================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.2.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11.0"
    }
  }

  # Local backend for development
  backend "local" {
    path = "terraform.tfstate"
  }
}

# ============================================================================
# Provider Configuration
# ============================================================================

provider "kind" {}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/config")
  }
}

# ============================================================================
# Local Variables
# ============================================================================

locals {
  cluster_name = "aiops-dev"

  # Namespaces to create
  namespaces = {
    ai-ops = {
      labels = {
        app     = "ai-ops-agent"
        managed = "terraform"
        env     = "development"
      }
    }
    monitoring = {
      labels = {
        app     = "observability"
        managed = "terraform"
        env     = "development"
      }
    }
    vault = {
      labels = {
        app     = "secrets"
        managed = "terraform"
        env     = "development"
      }
    }
  }

  # Common labels for all resources
  common_labels = {
    "managed-by" = "terraform"
    "project"    = "suhlabs"
    "component"  = "aiops-substrate"
  }
}

# ============================================================================
# Kind Cluster Resource
# ============================================================================

resource "kind_cluster" "default" {
  name = local.cluster_name

  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    # Control plane node
    node {
      role = "control-plane"

      # Port mappings for accessing services
      extra_port_mappings {
        container_port = 30080
        host_port      = 30080
        protocol       = "TCP"
      }

      extra_port_mappings {
        container_port = 30443
        host_port      = 30443
        protocol       = "TCP"
      }

      # Resource limits for control plane
      kubeadm_config_patches = [
        <<-EOT
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "node-role.kubernetes.io/control-plane="
        EOT
      ]
    }

    # Worker nodes
    node {
      role = "worker"

      kubeadm_config_patches = [
        <<-EOT
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "node-role.kubernetes.io/worker="
        EOT
      ]
    }

    node {
      role = "worker"

      kubeadm_config_patches = [
        <<-EOT
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "node-role.kubernetes.io/worker="
        EOT
      ]
    }
  }
}

# ============================================================================
# Kubernetes Namespaces
# ============================================================================

resource "kubernetes_namespace" "namespaces" {
  for_each = local.namespaces

  metadata {
    name   = each.key
    labels = merge(local.common_labels, each.value.labels)
  }

  depends_on = [kind_cluster.default]
}

# ============================================================================
# Service Accounts
# ============================================================================

resource "kubernetes_service_account" "ai_ops_agent" {
  metadata {
    name      = "ai-ops-agent"
    namespace = kubernetes_namespace.namespaces["ai-ops"].metadata[0].name
    labels    = local.common_labels
  }
}

# ============================================================================
# ConfigMap for AI Ops Agent
# ============================================================================

resource "kubernetes_config_map" "ai_ops_config" {
  metadata {
    name      = "ai-ops-config"
    namespace = kubernetes_namespace.namespaces["ai-ops"].metadata[0].name
    labels    = local.common_labels
  }

  data = {
    ENVIRONMENT      = "development"
    LOG_LEVEL        = "info"
    OLLAMA_HOST      = "http://ollama:11434"
    QDRANT_HOST      = "http://qdrant:6333"
    VAULT_ADDR       = "http://vault.vault.svc:8200"
  }
}

# ============================================================================
# Outputs
# ============================================================================

output "cluster_name" {
  description = "Name of the Kind cluster"
  value       = kind_cluster.default.name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = kind_cluster.default.endpoint
}

output "kubeconfig" {
  description = "Kubeconfig for accessing the cluster"
  value       = kind_cluster.default.kubeconfig
  sensitive   = true
}

output "namespaces" {
  description = "Created namespaces"
  value       = [for ns in kubernetes_namespace.namespaces : ns.metadata[0].name]
}

output "ai_ops_namespace" {
  description = "AI Ops namespace name"
  value       = kubernetes_namespace.namespaces["ai-ops"].metadata[0].name
}

output "service_account" {
  description = "AI Ops service account"
  value       = kubernetes_service_account.ai_ops_agent.metadata[0].name
}
