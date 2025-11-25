terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.2.1"
    }
  }
}

provider "kind" {}

resource "kind_cluster" "aiops" {
  name = "aiops-dev"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      extra_port_mappings {
        container_port = 30080
        host_port      = 30080
      }
    }

    node {
      role = "worker"
    }
  }
}
