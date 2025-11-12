# ============================================================================
# Kubernetes Namespace Module - Variables
# ============================================================================

variable "name" {
  description = "Name of the namespace"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.name))
    error_message = "Namespace name must consist of lowercase alphanumeric characters or '-', and must start and end with an alphanumeric character."
  }
}

variable "labels" {
  description = "Labels to apply to the namespace"
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Annotations to apply to the namespace"
  type        = map(string)
  default     = {}
}

variable "create_default_deny_policy" {
  description = "Whether to create a default deny-all network policy"
  type        = bool
  default     = false
}

variable "resource_quota" {
  description = "Resource quota limits for the namespace"
  type = object({
    pods                   = optional(string)
    requests_cpu           = optional(string)
    requests_memory        = optional(string)
    limits_cpu             = optional(string)
    limits_memory          = optional(string)
    persistentvolumeclaims = optional(string)
    services               = optional(string)
  })
  default = null
}

variable "limit_range" {
  description = "Default resource limits and requests for containers"
  type = object({
    default = optional(object({
      cpu    = optional(string)
      memory = optional(string)
    }))
    default_request = optional(object({
      cpu    = optional(string)
      memory = optional(string)
    }))
    max = optional(object({
      cpu    = optional(string)
      memory = optional(string)
    }))
    min = optional(object({
      cpu    = optional(string)
      memory = optional(string)
    }))
  })
  default = null
}
