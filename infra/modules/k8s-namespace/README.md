# Kubernetes Namespace Module

Reusable Terraform module for creating Kubernetes namespaces with optional resource quotas, limit ranges, and network policies.

## Features

- Creates a Kubernetes namespace with custom labels and annotations
- Optional default-deny network policy for zero-trust security
- Optional resource quotas to limit resource consumption
- Optional limit ranges to set default resource requests/limits
- Automatic timestamp labeling for tracking
- Managed-by label for Terraform tracking

## Usage

### Basic Namespace

```hcl
module "my_namespace" {
  source = "../../modules/k8s-namespace"

  name = "my-app"

  labels = {
    app = "my-application"
    env = "production"
  }
}
```

### Namespace with Network Policy

```hcl
module "secure_namespace" {
  source = "../../modules/k8s-namespace"

  name = "secure-app"

  labels = {
    app     = "secure-application"
    env     = "production"
    tier    = "backend"
  }

  # Creates a default deny-all network policy
  create_default_deny_policy = true
}
```

### Namespace with Resource Quotas

```hcl
module "limited_namespace" {
  source = "../../modules/k8s-namespace"

  name = "limited-app"

  resource_quota = {
    pods              = "10"
    requests_cpu      = "4"
    requests_memory   = "8Gi"
    limits_cpu        = "8"
    limits_memory     = "16Gi"
  }
}
```

### Namespace with Limit Ranges

```hcl
module "managed_namespace" {
  source = "../../modules/k8s-namespace"

  name = "managed-app"

  limit_range = {
    default = {
      cpu    = "500m"
      memory = "512Mi"
    }
    default_request = {
      cpu    = "100m"
      memory = "128Mi"
    }
    max = {
      cpu    = "2"
      memory = "2Gi"
    }
    min = {
      cpu    = "50m"
      memory = "64Mi"
    }
  }
}
```

### Full Example (Production Ready)

```hcl
module "production_namespace" {
  source = "../../modules/k8s-namespace"

  name = "ai-ops-production"

  labels = {
    app         = "ai-ops-agent"
    env         = "production"
    managed-by  = "terraform"
    team        = "platform"
  }

  annotations = {
    "description" = "AI Ops Agent production environment"
    "contact"     = "platform-team@example.com"
  }

  create_default_deny_policy = true

  resource_quota = {
    pods              = "50"
    requests_cpu      = "20"
    requests_memory   = "40Gi"
    limits_cpu        = "40"
    limits_memory     = "80Gi"
    services          = "20"
  }

  limit_range = {
    default = {
      cpu    = "1"
      memory = "1Gi"
    }
    default_request = {
      cpu    = "250m"
      memory = "256Mi"
    }
    max = {
      cpu    = "4"
      memory = "8Gi"
    }
    min = {
      cpu    = "100m"
      memory = "128Mi"
    }
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name | Name of the namespace | `string` | n/a | yes |
| labels | Labels to apply to the namespace | `map(string)` | `{}` | no |
| annotations | Annotations to apply to the namespace | `map(string)` | `{}` | no |
| create_default_deny_policy | Whether to create a default deny-all network policy | `bool` | `false` | no |
| resource_quota | Resource quota limits for the namespace | `object` | `null` | no |
| limit_range | Default resource limits and requests for containers | `object` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| name | The name of the namespace |
| id | The ID of the namespace |
| labels | The labels applied to the namespace |
| annotations | The annotations applied to the namespace |
| resource_quota_name | The name of the resource quota (if created) |
| limit_range_name | The name of the limit range (if created) |
| network_policy_name | The name of the default deny network policy (if created) |

## Security Best Practices

1. **Network Policies**: Always enable `create_default_deny_policy` for production namespaces
2. **Resource Quotas**: Set reasonable limits to prevent resource exhaustion
3. **Limit Ranges**: Define default requests/limits so developers don't need to remember
4. **Labels**: Use consistent labeling for better organization and network policy selectors

## Examples

See the `examples/` directory for more usage patterns.

## Requirements

- Terraform >= 1.6
- Kubernetes provider >= 2.23.0
- A working Kubernetes cluster

## License

Apache 2.0
