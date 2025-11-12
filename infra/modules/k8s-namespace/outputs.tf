# ============================================================================
# Kubernetes Namespace Module - Outputs
# ============================================================================

output "name" {
  description = "The name of the namespace"
  value       = kubernetes_namespace.this.metadata[0].name
}

output "id" {
  description = "The ID of the namespace"
  value       = kubernetes_namespace.this.id
}

output "labels" {
  description = "The labels applied to the namespace"
  value       = kubernetes_namespace.this.metadata[0].labels
}

output "annotations" {
  description = "The annotations applied to the namespace"
  value       = kubernetes_namespace.this.metadata[0].annotations
}

output "resource_quota_name" {
  description = "The name of the resource quota (if created)"
  value       = var.resource_quota != null ? kubernetes_resource_quota.this[0].metadata[0].name : null
}

output "limit_range_name" {
  description = "The name of the limit range (if created)"
  value       = var.limit_range != null ? kubernetes_limit_range.this[0].metadata[0].name : null
}

output "network_policy_name" {
  description = "The name of the default deny network policy (if created)"
  value       = var.create_default_deny_policy ? kubernetes_network_policy.default_deny[0].metadata[0].name : null
}
