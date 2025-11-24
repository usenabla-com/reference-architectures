# -----------------------------------------------------------------------------
# Identity Module
# Teleport Zero-Trust Access with JumpCloud SAML SSO
# CMMC IA.L2-3.5.3 - Multi-factor authentication
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Namespace for Identity Services
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "teleport" {
  metadata {
    name = "teleport"
    labels = {
      "app.kubernetes.io/name"             = "teleport"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}


# -----------------------------------------------------------------------------
# Teleport Configuration ConfigMap
# -----------------------------------------------------------------------------
resource "kubernetes_config_map" "teleport_config" {
  metadata {
    name      = "teleport-custom-config"
    namespace = kubernetes_namespace.teleport.metadata[0].name
  }

  data = {
    "teleport.yaml" = yamlencode({
      version = "v3"
      teleport = {
        nodename = "teleport"
        data_dir = "/var/lib/teleport"
        log = {
          output   = "stderr"
          severity = "INFO"
          format = {
            output = "json"
          }
        }
      }
      auth_service = {
        enabled = true
        authentication = {
          type          = "local"
          second_factor = var.teleport_config.second_factor
          webauthn = {
            rp_id = var.teleport_cluster_fqdn
          }
        }
        session_recording = "node-sync"
      }
      proxy_service = {
        enabled         = true
        web_listen_addr = "0.0.0.0:443"
        public_addr     = "${var.teleport_cluster_fqdn}:443"
      }
    })
  }
}

# -----------------------------------------------------------------------------
# Teleport Helm Release
# -----------------------------------------------------------------------------
resource "helm_release" "teleport" {
  name             = "teleport"
  repository       = "https://charts.releases.teleport.dev"
  chart            = "teleport-cluster"
  version          = var.teleport_version
  namespace        = kubernetes_namespace.teleport.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      clusterName = var.teleport_cluster_fqdn
      acme        = var.teleport_config.acme_enabled
      acmeEmail   = var.teleport_config.acme_email
      highAvailability = {
        replicaCount        = var.teleport_replicas
        requireAntiAffinity = true
      }
      proxyListenerMode = "multiplex"
      persistence = {
        enabled          = true
        storageClassName = "managed-csi-premium"
        size             = var.teleport_storage_size
      }
      service = {
        type = "LoadBalancer"
        annotations = {
          "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/readyz"
        }
      }
      podSecurityPolicy = {
        enabled = false
      }
      securityContext = {
        runAsNonRoot = true
        runAsUser    = 65532
      }
      resources = {
        requests = {
          cpu    = "250m"
          memory = "512Mi"
        }
        limits = {
          cpu    = "2"
          memory = "4Gi"
        }
      }
      log = {
        level  = "INFO"
        format = "json"
      }
    })
  ]
}

# -----------------------------------------------------------------------------
# Teleport Application Access Configuration
# Registers all workload apps with Teleport for unified authentication
# -----------------------------------------------------------------------------
resource "kubernetes_config_map" "teleport_apps" {
  metadata {
    name      = "teleport-apps-config"
    namespace = kubernetes_namespace.teleport.metadata[0].name
  }

  data = {
    "apps.yaml" = <<-YAML
kind: app
version: v3
metadata:
  name: code-server
  description: "VS Code in the browser"
  labels:
    env: production
    type: development
spec:
  uri: http://code-server.workloads.svc.cluster.local:8080
  public_addr: code.${var.teleport_cluster_fqdn}
---
kind: app
version: v3
metadata:
  name: mattermost
  description: "Team Chat"
  labels:
    env: production
    type: collaboration
spec:
  uri: http://mattermost.workloads.svc.cluster.local:8065
  public_addr: chat.${var.teleport_cluster_fqdn}
---
kind: app
version: v3
metadata:
  name: nextcloud
  description: "File Sharing"
  labels:
    env: production
    type: collaboration
spec:
  uri: http://nextcloud.workloads.svc.cluster.local:8080
  public_addr: files.${var.teleport_cluster_fqdn}
---
kind: app
version: v3
metadata:
  name: grafana
  description: "Monitoring Dashboards"
  labels:
    env: production
    type: observability
spec:
  uri: http://grafana.observability.svc.cluster.local:3000
  public_addr: grafana.${var.teleport_cluster_fqdn}
---
kind: app
version: v3
metadata:
  name: gatus
  description: "Status Page"
  labels:
    env: production
    type: observability
spec:
  uri: http://gatus.observability.svc.cluster.local:8080
  public_addr: status.${var.teleport_cluster_fqdn}
YAML
  }
}

# -----------------------------------------------------------------------------
# Teleport Roles ConfigMap - Applied via tctl after Teleport is ready
# -----------------------------------------------------------------------------
resource "kubernetes_config_map" "teleport_roles" {
  metadata {
    name      = "teleport-roles-config"
    namespace = kubernetes_namespace.teleport.metadata[0].name
  }

  data = {
    "admin-role.yaml" = <<-YAML
kind: role
version: v7
metadata:
  name: admin
spec:
  allow:
    logins:
      - root
      - admin
      - "{{internal.logins}}"
    node_labels:
      "*": "*"
    kubernetes_groups:
      - system:masters
    kubernetes_labels:
      "*": "*"
    kubernetes_resources:
      - kind: "*"
        namespace: "*"
        name: "*"
    db_labels:
      "*": "*"
    db_names:
      - "*"
    db_users:
      - "*"
    app_labels:
      "*": "*"
    rules:
      - resources:
          - "*"
        verbs:
          - "*"
  options:
    max_session_ttl: ${var.teleport_session_ttl}
    forward_agent: true
    port_forwarding: true
    permit_x11_forwarding: false
    record_session:
      default: best_effort
YAML

    "developer-role.yaml" = <<-YAML
kind: role
version: v7
metadata:
  name: developer
spec:
  allow:
    logins:
      - "{{internal.logins}}"
    node_labels:
      env:
        - dev
        - staging
    kubernetes_groups:
      - developers
    kubernetes_labels:
      env:
        - dev
        - staging
    kubernetes_resources:
      - kind: pod
        namespace: "*"
        name: "*"
        verbs:
          - get
          - list
          - watch
      - kind: deployment
        namespace: "*"
        name: "*"
        verbs:
          - get
          - list
          - watch
    db_labels:
      env:
        - dev
        - staging
    db_names:
      - development
      - staging
    db_users:
      - readonly
      - developer
    app_labels:
      "*": "*"
  deny:
    node_labels:
      env: production
    kubernetes_labels:
      env: production
  options:
    max_session_ttl: ${var.teleport_session_ttl}
    forward_agent: false
    port_forwarding: true
    record_session:
      default: best_effort
YAML

    "auditor-role.yaml" = <<-YAML
kind: role
version: v7
metadata:
  name: auditor
spec:
  allow:
    rules:
      - resources:
          - event
          - session
        verbs:
          - list
          - read
    app_labels:
      "*": "*"
    review_requests:
      roles:
        - "*"
  options:
    max_session_ttl: ${var.teleport_session_ttl}
    forward_agent: false
    port_forwarding: false
YAML

    "access-role.yaml" = <<-YAML
kind: role
version: v7
metadata:
  name: access
spec:
  allow:
    app_labels:
      "*": "*"
    request:
      roles:
        - developer
        - admin
      thresholds:
        - approve: 1
          deny: 1
  options:
    max_session_ttl: ${var.teleport_session_ttl}
    forward_agent: false
    port_forwarding: false
YAML
  }
}

# -----------------------------------------------------------------------------
# Job to apply Teleport configuration after deployment
# -----------------------------------------------------------------------------
resource "kubernetes_job" "teleport_config_apply" {
  depends_on = [
    helm_release.teleport,
    kubernetes_config_map.teleport_apps,
    kubernetes_config_map.teleport_roles
  ]

  metadata {
    name      = "teleport-config-apply"
    namespace = kubernetes_namespace.teleport.metadata[0].name
  }

  spec {
    ttl_seconds_after_finished = 300
    backoff_limit              = 3

    template {
      metadata {
        labels = {
          app = "teleport-config-apply"
        }
      }

      spec {
        restart_policy       = "OnFailure"
        service_account_name = "teleport"

        container {
          name  = "tctl"
          image = "public.ecr.aws/gravitational/teleport:${var.teleport_version}"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOF
            set -e
            echo "Waiting for Teleport to be ready..."
            sleep 30

            echo "Applying application access config..."
            tctl create -f /apps/apps.yaml || true

            echo "Applying roles..."
            for role in /roles/*.yaml; do
              echo "Applying $role..."
              tctl create -f "$role" || true
            done

            echo "Configuration applied successfully"
            EOF
          ]

          volume_mount {
            name       = "apps-config"
            mount_path = "/apps"
            read_only  = true
          }

          volume_mount {
            name       = "roles-config"
            mount_path = "/roles"
            read_only  = true
          }

          volume_mount {
            name       = "teleport-data"
            mount_path = "/var/lib/teleport"
          }

          env {
            name  = "TELEPORT_AUTH_SERVER"
            value = "teleport-auth.${kubernetes_namespace.teleport.metadata[0].name}.svc.cluster.local:3025"
          }
        }

        volume {
          name = "apps-config"
          config_map {
            name = kubernetes_config_map.teleport_apps.metadata[0].name
          }
        }

        volume {
          name = "roles-config"
          config_map {
            name = kubernetes_config_map.teleport_roles.metadata[0].name
          }
        }

        volume {
          name = "teleport-data"
          empty_dir {}
        }
      }
    }
  }

  wait_for_completion = false
}

# -----------------------------------------------------------------------------
# Network Policy for Teleport (Standard Kubernetes NetworkPolicy)
# -----------------------------------------------------------------------------
resource "kubernetes_network_policy" "teleport" {
  metadata {
    name      = "teleport-access"
    namespace = kubernetes_namespace.teleport.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        "app.kubernetes.io/name" = "teleport"
      }
    }

    ingress {
      from {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
      ports {
        port     = "443"
        protocol = "TCP"
      }
      ports {
        port     = "3080"
        protocol = "TCP"
      }
    }

    ingress {
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
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

# -----------------------------------------------------------------------------
# Teleport Kubernetes Operator
# Enables declarative management of Teleport resources via CRDs
# Customers create TeleportApp, TeleportUser, TeleportRole CRs
# -----------------------------------------------------------------------------
resource "helm_release" "teleport_operator" {
  name       = "teleport-operator"
  repository = "https://charts.releases.teleport.dev"
  chart      = "teleport-operator"
  version    = var.teleport_operator_version
  namespace  = kubernetes_namespace.teleport.metadata[0].name
  wait       = true
  timeout    = 300

  values = [
    yamlencode({
      # Connect to the Teleport cluster
      teleportAddress = "${var.teleport_cluster_fqdn}:443"

      # Use the auth token for operator authentication
      teleportClusterName = var.teleport_cluster_fqdn

      # Join method - use kubernetes for in-cluster auth
      joinMethod = "kubernetes"

      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
      }
    })
  ]

  depends_on = [helm_release.teleport]
}

# -----------------------------------------------------------------------------
# Teleport Bot for Operator Authentication
# The operator needs a bot identity to manage Teleport resources
# -----------------------------------------------------------------------------
resource "kubernetes_config_map" "teleport_operator_bot" {
  metadata {
    name      = "teleport-operator-bot-config"
    namespace = kubernetes_namespace.teleport.metadata[0].name
  }

  data = {
    "bot.yaml" = <<-YAML
kind: bot
version: v1
metadata:
  name: teleport-operator
spec:
  roles:
    - teleport-operator
  traits:
    - name: logins
      values: []
YAML

    "operator-role.yaml" = <<-YAML
kind: role
version: v7
metadata:
  name: teleport-operator
spec:
  allow:
    rules:
      # Allow managing apps
      - resources: [app]
        verbs: [list, create, read, update, delete]
      # Allow managing users (for sync)
      - resources: [user]
        verbs: [list, create, read, update, delete]
      # Allow managing roles
      - resources: [role]
        verbs: [list, create, read, update, delete]
      # Allow managing tokens for join
      - resources: [token]
        verbs: [list, create, read, update, delete]
YAML
  }

  depends_on = [helm_release.teleport]
}

# Job to create the operator bot and role
resource "kubernetes_job" "teleport_operator_setup" {
  depends_on = [
    helm_release.teleport,
    kubernetes_config_map.teleport_operator_bot
  ]

  metadata {
    name      = "teleport-operator-setup"
    namespace = kubernetes_namespace.teleport.metadata[0].name
  }

  spec {
    ttl_seconds_after_finished = 300
    backoff_limit              = 3

    template {
      metadata {
        labels = {
          app = "teleport-operator-setup"
        }
      }

      spec {
        restart_policy       = "OnFailure"
        service_account_name = "teleport"

        container {
          name  = "tctl"
          image = "public.ecr.aws/gravitational/teleport:${var.teleport_version}"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOF
            set -e
            echo "Waiting for Teleport to be ready..."
            sleep 60

            echo "Creating operator role..."
            tctl create -f /config/operator-role.yaml || true

            echo "Creating operator bot..."
            tctl create -f /config/bot.yaml || true

            echo "Teleport operator setup complete"
            EOF
          ]

          volume_mount {
            name       = "config"
            mount_path = "/config"
            read_only  = true
          }

          volume_mount {
            name       = "teleport-data"
            mount_path = "/var/lib/teleport"
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.teleport_operator_bot.metadata[0].name
          }
        }

        volume {
          name = "teleport-data"
          empty_dir {}
        }
      }
    }
  }

  wait_for_completion = false
}
