# -----------------------------------------------------------------------------
# Workloads Module
# Code-Server, Open-WebUI, Mattermost, Nextcloud
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Namespace
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "workloads" {
  metadata {
    name = "workloads"
    labels = {
      "app.kubernetes.io/name"             = "workloads"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# -----------------------------------------------------------------------------
# Code-Server (VS Code in browser)
# -----------------------------------------------------------------------------
resource "kubernetes_deployment" "code_server" {
  metadata {
    name      = "code-server"
    namespace = kubernetes_namespace.workloads.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "code-server"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "code-server"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "code-server"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }

        container {
          name  = "code-server"
          image = "codercom/code-server:${var.code_server_version}"

          port {
            name           = "http"
            container_port = 8080
          }

          env {
            name  = "PASSWORD"
            value = ""  # Set via secret in production
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2"
              memory = "4Gi"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/home/coder"
          }

          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.code_server_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "code_server_data" {
  metadata {
    name      = "code-server-data"
    namespace = kubernetes_namespace.workloads.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "managed-csi-premium"

    resources {
      requests = {
        storage = "50Gi"
      }
    }
  }
}

resource "kubernetes_service" "code_server" {
  metadata {
    name      = "code-server"
    namespace = kubernetes_namespace.workloads.metadata[0].name
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "code-server"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

# -----------------------------------------------------------------------------
# Open-WebUI (LLM Interface)
# -----------------------------------------------------------------------------
resource "kubernetes_deployment" "open_webui" {
  metadata {
    name      = "open-webui"
    namespace = kubernetes_namespace.workloads.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "open-webui"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "open-webui"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "open-webui"
        }
      }

      spec {
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }

        container {
          name  = "open-webui"
          image = "ghcr.io/open-webui/open-webui:${var.open_webui_version}"

          port {
            name           = "http"
            container_port = 8080
          }

          env {
            name  = "WEBUI_AUTH"
            value = "true"
          }

          env {
            name  = "DATA_DIR"
            value = "/app/backend/data"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "512Mi"
            }
            limits = {
              cpu    = "1"
              memory = "2Gi"
            }
          }

          volume_mount {
            name       = "data"
            mount_path = "/app/backend/data"
          }

          security_context {
            allow_privilege_escalation = false
            run_as_non_root            = true
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.open_webui_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "open_webui_data" {
  metadata {
    name      = "open-webui-data"
    namespace = kubernetes_namespace.workloads.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "managed-csi-premium"

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}

resource "kubernetes_service" "open_webui" {
  metadata {
    name      = "open-webui"
    namespace = kubernetes_namespace.workloads.metadata[0].name
  }

  spec {
    selector = {
      "app.kubernetes.io/name" = "open-webui"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

# -----------------------------------------------------------------------------
# Mattermost (Team Chat)
# -----------------------------------------------------------------------------
resource "random_password" "mattermost_db_password" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "mattermost_db" {
  metadata {
    name      = "mattermost-db"
    namespace = kubernetes_namespace.workloads.metadata[0].name
  }

  data = {
    DB_HOST     = var.postgres_host
    DB_USER     = "mattermost"
    DB_PASSWORD = random_password.mattermost_db_password.result
  }

  type = "Opaque"
}

resource "helm_release" "mattermost" {
  name             = "mattermost"
  repository       = "https://helm.mattermost.com"
  chart            = "mattermost-team-edition"
  version          = var.mattermost_version
  namespace        = kubernetes_namespace.workloads.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      persistence = {
        data = {
          enabled      = true
          size         = "50Gi"
          storageClass = "managed-csi-premium"
        }
        plugins = {
          enabled      = true
          size         = "5Gi"
          storageClass = "managed-csi-premium"
        }
      }
      externalDB = {
        enabled = true
        externalDriverType = "postgres"
        externalConnectionString = "postgres://mattermost:${random_password.mattermost_db_password.result}@${var.postgres_host}:5432/mattermost?sslmode=require"
      }
      mysql = {
        enabled = false
      }
      resources = {
        requests = {
          cpu    = "250m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "1"
          memory = "2Gi"
        }
      }
      ingress = {
        enabled = false  # Using Teleport for access
      }
    })
  ]
}

# -----------------------------------------------------------------------------
# Nextcloud (File Sharing)
# -----------------------------------------------------------------------------
resource "random_password" "nextcloud_admin_password" {
  length  = 32
  special = false
}

resource "random_password" "nextcloud_db_password" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "nextcloud_credentials" {
  metadata {
    name      = "nextcloud-credentials"
    namespace = kubernetes_namespace.workloads.metadata[0].name
  }

  data = {
    nextcloud-username = "admin"
    nextcloud-password = random_password.nextcloud_admin_password.result
  }

  type = "Opaque"
}

resource "helm_release" "nextcloud" {
  name             = "nextcloud"
  repository       = "https://nextcloud.github.io/helm"
  chart            = "nextcloud"
  version          = var.nextcloud_version
  namespace        = kubernetes_namespace.workloads.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      nextcloud = {
        host = "nextcloud.workloads.svc.cluster.local"
        existingSecret = {
          enabled    = true
          secretName = kubernetes_secret.nextcloud_credentials.metadata[0].name
        }
      }
      internalDatabase = {
        enabled = false
      }
      externalDatabase = {
        enabled  = true
        type     = "postgresql"
        host     = var.postgres_host
        database = "nextcloud"
        user     = "nextcloud"
        password = random_password.nextcloud_db_password.result
      }
      persistence = {
        enabled      = true
        size         = "100Gi"
        storageClass = "managed-csi-premium"
      }
      resources = {
        requests = {
          cpu    = "250m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "2"
          memory = "2Gi"
        }
      }
      ingress = {
        enabled = false  # Using Teleport for access
      }
      livenessProbe = {
        enabled = true
      }
      readinessProbe = {
        enabled = true
      }
      cronjob = {
        enabled = true
      }
      redis = {
        enabled = true
      }
    })
  ]
}

# -----------------------------------------------------------------------------
# Network Policy
# -----------------------------------------------------------------------------
resource "kubernetes_network_policy" "workloads" {
  metadata {
    name      = "workloads-access"
    namespace = kubernetes_namespace.workloads.metadata[0].name
  }

  spec {
    pod_selector {}

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "teleport"
          }
        }
      }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "workloads"
          }
        }
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
