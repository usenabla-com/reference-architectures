# -----------------------------------------------------------------------------
# Observability Module
# Prometheus Stack + Gatus Health Monitoring
# CMMC AU.L2-3.3.1 - System Monitoring and Audit
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Namespace
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
    labels = {
      "app.kubernetes.io/name"             = "observability"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

# -----------------------------------------------------------------------------
# Prometheus Stack (includes Grafana, AlertManager)
# -----------------------------------------------------------------------------
resource "helm_release" "prometheus_stack" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.prometheus_version
  namespace        = kubernetes_namespace.observability.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 900

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention         = "${var.retention_days}d"
          retentionSize     = "45GB"
          scrapeInterval    = "30s"
          evaluationInterval = "30s"
          resources = {
            requests = {
              cpu    = "500m"
              memory = "2Gi"
            }
            limits = {
              cpu    = "2"
              memory = "4Gi"
            }
          }
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "managed-csi-premium"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "50Gi"
                  }
                }
              }
            }
          }
          serviceMonitorSelectorNilUsesHelmValues = false
          podMonitorSelectorNilUsesHelmValues     = false
        }
      }
      alertmanager = {
        alertmanagerSpec = {
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
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = "managed-csi-premium"
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }
        }
      }
      grafana = {
        enabled = true
        adminPassword = "admin"  # Should be changed post-deployment
        persistence = {
          enabled          = true
          storageClassName = "managed-csi-premium"
          size             = "10Gi"
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
        sidecar = {
          dashboards = {
            enabled = true
          }
          datasources = {
            enabled = true
          }
        }
      }
      kubeStateMetrics = {
        enabled = true
      }
      nodeExporter = {
        enabled = true
      }
      prometheusOperator = {
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
      }
    })
  ]
}

# -----------------------------------------------------------------------------
# Gatus - Health/Status Page
# -----------------------------------------------------------------------------
resource "helm_release" "gatus" {
  name             = "gatus"
  repository       = "https://minicloudlabs.github.io/helm-charts"
  chart            = "gatus"
  version          = var.gatus_version
  namespace        = kubernetes_namespace.observability.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      config = {
        storage = {
          type = "memory"
        }
        endpoints = [
          {
            name  = "Teleport Proxy"
            group = "identity"
            url   = "https://teleport.teleport.svc.cluster.local:443/webapi/ping"
            interval = "60s"
            conditions = [
              "[STATUS] == 200"
            ]
          },
          {
            name  = "OpenBao"
            group = "secrets"
            url   = "http://openbao.openbao.svc.cluster.local:8200/v1/sys/health"
            interval = "60s"
            conditions = [
              "[STATUS] == 200"
            ]
          },
          {
            name  = "OPAL Server"
            group = "policy"
            url   = "http://opal-server.policy-system.svc.cluster.local:7002/healthz"
            interval = "60s"
            conditions = [
              "[STATUS] == 200"
            ]
          },
          {
            name  = "Cedar PDP"
            group = "policy"
            url   = "http://cedar-pdp.policy-system.svc.cluster.local:8180/health"
            interval = "60s"
            conditions = [
              "[STATUS] == 200"
            ]
          },
          {
            name  = "PostgreSQL"
            group = "data"
            url   = "tcp://enclave-postgres-rw.postgres.svc.cluster.local:5432"
            interval = "60s"
            conditions = [
              "[CONNECTED] == true"
            ]
          },
          {
            name  = "MinIO"
            group = "data"
            url   = "http://minio.minio.svc.cluster.local:9000/minio/health/live"
            interval = "60s"
            conditions = [
              "[STATUS] == 200"
            ]
          },
          {
            name  = "Prometheus"
            group = "observability"
            url   = "http://prometheus-kube-prometheus-prometheus.observability.svc.cluster.local:9090/-/healthy"
            interval = "60s"
            conditions = [
              "[STATUS] == 200"
            ]
          }
        ]
        ui = {
          title = "Nabla Enclave Status"
        }
      }
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "200m"
          memory = "128Mi"
        }
      }
      service = {
        type = "ClusterIP"
        port = 8080
      }
    })
  ]
}

# -----------------------------------------------------------------------------
# Network Policy
# -----------------------------------------------------------------------------
resource "kubernetes_network_policy" "observability" {
  metadata {
    name      = "observability-access"
    namespace = kubernetes_namespace.observability.metadata[0].name
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
