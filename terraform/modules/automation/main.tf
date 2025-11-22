# -----------------------------------------------------------------------------
# Automation Module
# GitHub Actions Runner Controller
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Namespace
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "automation" {
  metadata {
    name = "automation"
    labels = {
      "app.kubernetes.io/name"             = "automation"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# -----------------------------------------------------------------------------
# GitHub Actions Runner Controller
# -----------------------------------------------------------------------------
resource "helm_release" "actions_runner_controller" {
  name             = "actions-runner-controller"
  repository       = "https://actions-runner-controller.github.io/actions-runner-controller"
  chart            = "actions-runner-controller"
  version          = var.actions_runner_version
  namespace        = kubernetes_namespace.automation.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      replicaCount = 2
      syncPeriod   = "1m"
      authSecret = {
        enabled = true
        create  = false
        name    = "github-auth"
      }
      resources = {
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
      metrics = {
        serviceMonitor = {
          enabled = true
        }
      }
    })
  ]
}

# Placeholder secret for GitHub auth - must be populated with actual credentials
resource "kubernetes_secret" "github_auth" {
  metadata {
    name      = "github-auth"
    namespace = kubernetes_namespace.automation.metadata[0].name
    labels = {
      "app.kubernetes.io/name" = "actions-runner-controller"
    }
  }

  data = {
    github_app_id              = ""
    github_app_installation_id = ""
    github_app_private_key     = ""
  }

  type = "Opaque"

  lifecycle {
    ignore_changes = [data]
  }
}

# Runner Deployment configuration
resource "kubernetes_config_map" "runner_deployment" {
  metadata {
    name      = "runner-deployment-config"
    namespace = kubernetes_namespace.automation.metadata[0].name
  }

  data = {
    "runner-deployment.yaml" = <<-YAML
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: enclave-runners
  namespace: automation
spec:
  replicas: 2
  template:
    spec:
      repository: ""  # Set to your repository
      labels:
        - self-hosted
        - linux
        - enclave
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
        limits:
          cpu: "2"
          memory: "4Gi"
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
YAML
  }
}

# -----------------------------------------------------------------------------
# Network Policy
# -----------------------------------------------------------------------------
resource "kubernetes_network_policy" "automation" {
  metadata {
    name      = "automation-access"
    namespace = kubernetes_namespace.automation.metadata[0].name
  }

  spec {
    pod_selector {}

    ingress {
      from {
        namespace_selector {}
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
