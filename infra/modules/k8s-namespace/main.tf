# ============================================================================
# Kubernetes Namespace Module
# Reusable module for creating Kubernetes namespaces with labels
# ============================================================================

resource "kubernetes_namespace" "this" {
  metadata {
    name = var.name

    labels = merge(
      var.labels,
      {
        "managed-by" = "terraform"
        "created-at" = timestamp()
      }
    )

    annotations = var.annotations
  }
}

# Optional: Create a default network policy for the namespace
resource "kubernetes_network_policy" "default_deny" {
  count = var.create_default_deny_policy ? 1 : 0

  metadata {
    name      = "default-deny-all"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    pod_selector {}

    policy_types = ["Ingress", "Egress"]
  }
}

# Optional: Create a resource quota for the namespace
resource "kubernetes_resource_quota" "this" {
  count = var.resource_quota != null ? 1 : 0

  metadata {
    name      = "${var.name}-quota"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    hard = var.resource_quota
  }
}

# Optional: Create a limit range for the namespace
resource "kubernetes_limit_range" "this" {
  count = var.limit_range != null ? 1 : 0

  metadata {
    name      = "${var.name}-limits"
    namespace = kubernetes_namespace.this.metadata[0].name
  }

  spec {
    limit {
      type = "Container"

      default = var.limit_range.default
      default_request = var.limit_range.default_request
      max    = var.limit_range.max
      min    = var.limit_range.min
    }
  }
}
