# Kubernetes Security and Compliance Policies
# OPA Rego policy for conftest validation

package main

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Deny containers without resource limits
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits
    msg := sprintf("Container '%s' must have resource limits defined", [container.name])
}

# Deny containers without resource requests
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.requests
    msg := sprintf("Container '%s' must have resource requests defined", [container.name])
}

# Deny privileged containers
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.privileged == true
    msg := sprintf("Container '%s' cannot run in privileged mode", [container.name])
}

# Deny running as root
deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.securityContext.runAsNonRoot
    msg := "Pod must set runAsNonRoot: true"
}

# Warn about using latest tag
warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf("Container '%s' uses 'latest' tag - use specific versions", [container.name])
}

# Deny missing liveness probe (except for init containers)
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.livenessProbe
    msg := sprintf("Container '%s' must have a liveness probe", [container.name])
}

# Deny missing readiness probe (except for init containers)
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.readinessProbe
    msg := sprintf("Container '%s' must have a readiness probe", [container.name])
}

# Deny hostNetwork unless explicitly allowed
deny[msg] {
    input.kind == "Deployment"
    input.spec.template.spec.hostNetwork == true
    not input.metadata.annotations["security.allowed/hostNetwork"]
    msg := "hostNetwork is not allowed without explicit annotation"
}

# Deny hostPID
deny[msg] {
    input.kind == "Deployment"
    input.spec.template.spec.hostPID == true
    msg := "hostPID is not allowed"
}

# Deny hostIPC
deny[msg] {
    input.kind == "Deployment"
    input.spec.template.spec.hostIPC == true
    msg := "hostIPC is not allowed"
}

# Require labels
deny[msg] {
    input.kind == "Deployment"
    not input.metadata.labels.app
    msg := "Deployment must have 'app' label"
}

# Require selector match
deny[msg] {
    input.kind == "Deployment"
    input.spec.selector.matchLabels.app != input.metadata.labels.app
    msg := "Deployment selector must match metadata labels"
}

# Certificate validation - must have valid DNS names
deny[msg] {
    input.kind == "Certificate"
    count(input.spec.dnsNames) == 0
    msg := "Certificate must have at least one DNS name"
}

# Certificate validation - must use proper issuer
deny[msg] {
    input.kind == "Certificate"
    not input.spec.issuerRef
    msg := "Certificate must reference an issuer"
}

# Service validation - must have selector
deny[msg] {
    input.kind == "Service"
    not input.spec.selector
    msg := "Service must have a selector"
}

# Warn about ClusterIP None (headless service)
warn[msg] {
    input.kind == "Service"
    input.spec.clusterIP == "None"
    msg := "Service is headless (clusterIP: None) - ensure this is intentional"
}

# Require TLS for ingress
deny[msg] {
    input.kind == "Ingress"
    not input.spec.tls
    msg := "Ingress must have TLS configured"
}

# Block dangerous capabilities
deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    capability := container.securityContext.capabilities.add[_]
    dangerous := ["SYS_ADMIN", "NET_ADMIN", "SYS_MODULE"]
    capability == dangerous[_]
    msg := sprintf("Container '%s' adds dangerous capability '%s'", [container.name, capability])
}

# Require dropped capabilities
warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.securityContext.capabilities.drop
    msg := sprintf("Container '%s' should drop capabilities (e.g., ALL)", [container.name])
}

# Require read-only root filesystem (with exceptions)
warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.securityContext.readOnlyRootFilesystem
    msg := sprintf("Container '%s' should use readOnlyRootFilesystem: true", [container.name])
}

# Check for proper image registry
warn[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not contains(container.image, ".")  # No registry specified
    msg := sprintf("Container '%s' should use fully qualified image name with registry", [container.name])
}

# Ensure namespace is specified
warn[msg] {
    input.kind in ["Deployment", "Service", "Certificate"]
    not input.metadata.namespace
    msg := "Resource should have namespace explicitly specified"
}
