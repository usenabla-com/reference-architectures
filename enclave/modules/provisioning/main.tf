# -----------------------------------------------------------------------------
# Provisioning Module
# Platform namespace for Nabla system resources
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Namespace for Platform Resources
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "nabla_system" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name"             = "nabla-system"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# -----------------------------------------------------------------------------
# Workloads Namespace (Standard)
# Where customer applications are deployed
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "workloads" {
  metadata {
    name = "workloads"
    labels = {
      "app.kubernetes.io/name"             = "workloads"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "usenabla.com/data-classification"   = "internal"
    }
  }
}

# -----------------------------------------------------------------------------
# Workloads CUI Namespace (Isolated for CUI workloads)
# Only created if CUI is enabled - runs on FIPS nodes
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "workloads_cui" {
  count = var.cui_enabled ? 1 : 0

  metadata {
    name = "workloads-cui"
    labels = {
      "app.kubernetes.io/name"             = "workloads-cui"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "usenabla.com/data-classification"   = "cui"
      "usenabla.com/isolation-boundary"    = "cui"
    }
  }
}

# -----------------------------------------------------------------------------
# Network Policy: Workloads namespace isolation
# -----------------------------------------------------------------------------
resource "kubernetes_network_policy" "workloads_default" {
  metadata {
    name      = "default-deny-ingress"
    namespace = kubernetes_namespace.workloads.metadata[0].name
  }

  spec {
    pod_selector {}

    # Allow ingress from Teleport proxy
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "teleport"
          }
        }
      }
    }

    # Allow ingress from same namespace
    ingress {
      from {
        pod_selector {}
      }
    }

    policy_types = ["Ingress"]
  }
}

# -----------------------------------------------------------------------------
# Network Policy: CUI Workloads namespace strict isolation
# -----------------------------------------------------------------------------
resource "kubernetes_network_policy" "workloads_cui_isolation" {
  count = var.cui_enabled ? 1 : 0

  metadata {
    name      = "cui-strict-isolation"
    namespace = kubernetes_namespace.workloads_cui[0].metadata[0].name
  }

  spec {
    pod_selector {}

    # Only allow ingress from Teleport proxy
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "teleport"
          }
        }
      }
    }

    # Allow ingress from same namespace (CUI workloads can talk to each other)
    ingress {
      from {
        pod_selector {}
      }
    }

    # Egress only to CUI data tier
    egress {
      to {
        namespace_selector {
          match_labels = {
            "usenabla.com/isolation-boundary" = "cui"
          }
        }
      }
    }

    # DNS
    egress {
      to {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
      }
      ports {
        port     = "53"
        protocol = "UDP"
      }
    }

    policy_types = ["Ingress", "Egress"]
  }
}
