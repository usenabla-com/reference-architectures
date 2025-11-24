# -----------------------------------------------------------------------------
# Policy Module
# OPAL (Open Policy Administration Layer) + Cedar Policy Engine
# CMMC AC.L2-3.1.1 - Access Control Policy Enforcement
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Namespace for Policy Services
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "policy" {
  metadata {
    name = "policy-system"
    labels = {
      "app.kubernetes.io/name"             = "policy-system"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# -----------------------------------------------------------------------------
# OPAL Server Configuration Secret
# -----------------------------------------------------------------------------
resource "kubernetes_secret" "opal_config" {
  metadata {
    name      = "opal-config"
    namespace = kubernetes_namespace.policy.metadata[0].name
  }

  data = {
    OPAL_POLICY_REPO_URL         = var.opal_config.policy_repo_url
    OPAL_POLICY_REPO_SSH_KEY     = var.opal_config.policy_repo_ssh_key
    OPAL_POLICY_REPO_MAIN_BRANCH = var.opal_config.policy_repo_branch
  }

  type = "Opaque"
}

# -----------------------------------------------------------------------------
# OPAL Server Deployment
# -----------------------------------------------------------------------------
resource "kubernetes_deployment" "opal_server" {
  metadata {
    name      = "opal-server"
    namespace = kubernetes_namespace.policy.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "opal-server"
      "app.kubernetes.io/component" = "policy-admin"
    }
  }

  spec {
    replicas = var.opal_config.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "opal-server"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "opal-server"
          "app.kubernetes.io/component" = "policy-admin"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 65532
          fs_group        = 65532
        }

        container {
          name  = "opal-server"
          image = "permitio/opal-server:${var.opal_version}"

          port {
            name           = "http"
            container_port = 7002
          }

          env {
            name  = "OPAL_BROADCAST_URI"
            value = "postgres://opal:opal@opal-postgres:5432/opal"
          }

          env {
            name = "OPAL_DATA_CONFIG_SOURCES"
            value = jsonencode({
              config = {
                entries = [
                  {
                    url    = "http://opal-server:7002/policy-data"
                    topics = ["policy_data"]
                    config = {
                      fetcher = "HttpFetcher"
                    }
                  }
                ]
              }
            })
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.opal_config.metadata[0].name
            }
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = 7002
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = 7002
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            capabilities {
              drop = ["ALL"]
            }
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# OPAL Server Service
# -----------------------------------------------------------------------------
resource "kubernetes_service" "opal_server" {
  metadata {
    name      = "opal-server"
    namespace = kubernetes_namespace.policy.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "opal-server"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "opal-server"
    }

    port {
      name        = "http"
      port        = 7002
      target_port = 7002
    }

    type = "ClusterIP"
  }
}

# -----------------------------------------------------------------------------
# Cedar Policy Decision Point (PDP) with OPAL Client
# -----------------------------------------------------------------------------
resource "kubernetes_deployment" "cedar_pdp" {
  metadata {
    name      = "cedar-pdp"
    namespace = kubernetes_namespace.policy.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "cedar-pdp"
      "app.kubernetes.io/component" = "policy-decision"
    }
  }

  spec {
    replicas = var.opal_config.replicas

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "cedar-pdp"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "cedar-pdp"
          "app.kubernetes.io/component" = "policy-decision"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 65532
          fs_group        = 65532
        }

        # OPAL Client sidecar
        container {
          name  = "opal-client"
          image = "permitio/opal-client:${var.opal_version}"

          port {
            name           = "http"
            container_port = 7000
          }

          env {
            name  = "OPAL_SERVER_URL"
            value = "http://opal-server:7002"
          }

          env {
            name  = "OPAL_POLICY_STORE_TYPE"
            value = "CEDAR"
          }

          env {
            name  = "OPAL_INLINE_CEDAR_ENABLED"
            value = "true"
          }

          resources {
            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "policy-store"
            mount_path = "/policy"
          }
        }

        # Cedar Agent
        container {
          name  = "cedar-agent"
          image = "permitio/cedar-agent:${var.cedar_agent_version}"

          port {
            name           = "http"
            container_port = 8180
          }

          env {
            name  = "CEDAR_POLICY_STORE_PATH"
            value = "/policy"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "256Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 8180
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8180
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          security_context {
            allow_privilege_escalation = false
            read_only_root_filesystem  = true
            run_as_non_root            = true
            capabilities {
              drop = ["ALL"]
            }
          }

          volume_mount {
            name       = "policy-store"
            mount_path = "/policy"
          }
        }

        volume {
          name = "policy-store"
          empty_dir {}
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Cedar PDP Service
# -----------------------------------------------------------------------------
resource "kubernetes_service" "cedar_pdp" {
  metadata {
    name      = "cedar-pdp"
    namespace = kubernetes_namespace.policy.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "cedar-pdp"
    }
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "cedar-pdp"
    }

    port {
      name        = "opal"
      port        = 7000
      target_port = 7000
    }

    port {
      name        = "cedar"
      port        = 8180
      target_port = 8180
    }

    type = "ClusterIP"
  }
}

# -----------------------------------------------------------------------------
# Default Cedar Policies ConfigMap
# -----------------------------------------------------------------------------
resource "kubernetes_config_map" "cedar_policies" {
  metadata {
    name      = "cedar-default-policies"
    namespace = kubernetes_namespace.policy.metadata[0].name
  }

  data = {
    "default.cedar" = <<-CEDAR
// Default deny policy - Zero Trust
forbid (
  principal,
  action,
  resource
);

// Allow authenticated users to read their own resources
permit (
  principal,
  action == Action::"read",
  resource
) when {
  principal == resource.owner
};

// Allow admins full access
permit (
  principal in Group::"Administrators",
  action,
  resource
);

// Allow developers access to non-production resources
permit (
  principal in Group::"Developers",
  action,
  resource
) when {
  resource.environment != "production"
};

// Allow auditors read-only access to audit logs
permit (
  principal in Group::"Auditors",
  action == Action::"read",
  resource in ResourceType::"AuditLog"
);
CEDAR

    "rbac.cedar" = <<-CEDAR
// Role-based access control policies

// Service accounts can access their designated namespaces
permit (
  principal is ServiceAccount,
  action,
  resource
) when {
  principal.namespace == resource.namespace
};

// Allow workloads to communicate within same namespace
permit (
  principal is Workload,
  action == Action::"connect",
  resource is Workload
) when {
  principal.namespace == resource.namespace
};
CEDAR
  }
}

# -----------------------------------------------------------------------------
# Network Policy for Policy System
# -----------------------------------------------------------------------------
resource "kubernetes_network_policy" "policy_system" {
  metadata {
    name      = "policy-system-access"
    namespace = kubernetes_namespace.policy.metadata[0].name
  }

  spec {
    pod_selector {}

    ingress {
      from {
        namespace_selector {}
      }
      ports {
        port     = "7002"
        protocol = "TCP"
      }
      ports {
        port     = "7000"
        protocol = "TCP"
      }
      ports {
        port     = "8180"
        protocol = "TCP"
      }
    }

    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
    }

    policy_types = ["Ingress", "Egress"]
  }
}
