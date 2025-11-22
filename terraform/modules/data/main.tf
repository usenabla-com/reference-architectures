# -----------------------------------------------------------------------------
# Data Module
# CloudNative-PG PostgreSQL + MinIO S3-Compatible Storage
# CMMC SC.L2-3.13.16 - Data at Rest Protection
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Namespaces
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "postgres" {
  metadata {
    name = "postgres"
    labels = {
      "app.kubernetes.io/name"             = "postgres"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

resource "kubernetes_namespace" "minio" {
  metadata {
    name = "minio"
    labels = {
      "app.kubernetes.io/name"             = "minio"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# -----------------------------------------------------------------------------
# CloudNative-PG Operator
# -----------------------------------------------------------------------------
resource "helm_release" "cnpg_operator" {
  name             = "cnpg"
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  version          = var.cnpg_version
  namespace        = "cnpg-system"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
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
      monitoring = {
        podMonitorEnabled = true
      }
    })
  ]
}

# -----------------------------------------------------------------------------
# PostgreSQL Cluster Configuration
# -----------------------------------------------------------------------------
resource "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = "postgres-superuser"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  data = {
    username = "postgres"
    password = random_password.postgres_password.result
  }

  type = "kubernetes.io/basic-auth"
}

resource "random_password" "postgres_password" {
  length  = 32
  special = false
}

resource "kubernetes_config_map" "cnpg_cluster" {
  depends_on = [helm_release.cnpg_operator]

  metadata {
    name      = "enclave-postgres-cluster"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  data = {
    "cluster.yaml" = <<-YAML
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: enclave-postgres
  namespace: ${kubernetes_namespace.postgres.metadata[0].name}
spec:
  instances: ${var.postgres_config.instances}
  primaryUpdateStrategy: unsupervised

  storage:
    size: ${var.postgres_config.storage_size}
    storageClass: ${var.postgres_config.storage_class}

  postgresql:
    parameters:
      max_connections: "200"
      shared_buffers: "256MB"
      effective_cache_size: "768MB"
      maintenance_work_mem: "128MB"
      checkpoint_completion_target: "0.9"
      wal_buffers: "16MB"
      default_statistics_target: "100"
      random_page_cost: "1.1"
      effective_io_concurrency: "200"
      work_mem: "4MB"
      min_wal_size: "1GB"
      max_wal_size: "4GB"
      max_worker_processes: "4"
      max_parallel_workers_per_gather: "2"
      max_parallel_workers: "4"
      max_parallel_maintenance_workers: "2"
      # Security settings
      ssl: "on"
      ssl_min_protocol_version: "TLSv1.3"
      password_encryption: "scram-sha-256"
      log_connections: "on"
      log_disconnections: "on"
      log_statement: "ddl"
    pg_hba:
      - host all all 10.0.0.0/8 scram-sha-256
      - hostssl all all 0.0.0.0/0 scram-sha-256

  bootstrap:
    initdb:
      database: enclave
      owner: enclave
      secret:
        name: postgres-superuser

  superuserSecret:
    name: postgres-superuser

  monitoring:
    enablePodMonitor: true

  backup:
    barmanObjectStore:
      destinationPath: s3://postgres-backups/
      endpointURL: http://minio.minio.svc.cluster.local:9000
      s3Credentials:
        accessKeyId:
          name: minio-postgres-credentials
          key: accesskey
        secretAccessKey:
          name: minio-postgres-credentials
          key: secretkey
      wal:
        compression: gzip
      data:
        compression: gzip
    retentionPolicy: "30d"

  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "4Gi"

  affinity:
    podAntiAffinityType: required
YAML
  }
}

# Job to apply the CNPG cluster
resource "kubernetes_job" "apply_cnpg_cluster" {
  depends_on = [
    helm_release.cnpg_operator,
    kubernetes_config_map.cnpg_cluster,
    kubernetes_secret.postgres_credentials
  ]

  metadata {
    name      = "apply-cnpg-cluster"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  spec {
    ttl_seconds_after_finished = 300
    backoff_limit              = 3

    template {
      metadata {
        labels = {
          app = "cnpg-cluster-apply"
        }
      }

      spec {
        restart_policy       = "OnFailure"
        service_account_name = "default"

        container {
          name  = "kubectl"
          image = "bitnami/kubectl:latest"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOF
            set -e
            echo "Waiting for CNPG operator..."
            sleep 30
            echo "Applying PostgreSQL cluster..."
            kubectl apply -f /config/cluster.yaml
            echo "PostgreSQL cluster applied"
            EOF
          ]

          volume_mount {
            name       = "config"
            mount_path = "/config"
            read_only  = true
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.cnpg_cluster.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_completion = false
}

# -----------------------------------------------------------------------------
# MinIO Operator
# -----------------------------------------------------------------------------
resource "helm_release" "minio_operator" {
  name             = "minio-operator"
  repository       = "https://operator.min.io"
  chart            = "operator"
  version          = var.minio_operator_version
  namespace        = "minio-operator"
  create_namespace = true
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      operator = {
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
      console = {
        enabled = true
      }
    })
  ]
}

# -----------------------------------------------------------------------------
# MinIO Tenant Credentials
# -----------------------------------------------------------------------------
resource "random_password" "minio_root_password" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "minio_credentials" {
  metadata {
    name      = "minio-credentials"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }

  data = {
    accesskey = "enclave-admin"
    secretkey = random_password.minio_root_password.result
  }

  type = "Opaque"
}

# MinIO credentials for PostgreSQL backups
resource "kubernetes_secret" "minio_postgres_credentials" {
  metadata {
    name      = "minio-postgres-credentials"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  data = {
    accesskey = "postgres-backup"
    secretkey = random_password.minio_postgres_password.result
  }

  type = "Opaque"
}

resource "random_password" "minio_postgres_password" {
  length  = 32
  special = false
}

# -----------------------------------------------------------------------------
# MinIO Tenant Configuration
# -----------------------------------------------------------------------------
resource "kubernetes_config_map" "minio_tenant" {
  depends_on = [helm_release.minio_operator]

  metadata {
    name      = "minio-tenant-config"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }

  data = {
    "tenant.yaml" = <<-YAML
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: enclave-minio
  namespace: ${kubernetes_namespace.minio.metadata[0].name}
spec:
  image: minio/minio:RELEASE.2024-01-16T16-07-38Z
  pools:
    - servers: ${var.minio_config.servers}
      volumesPerServer: ${var.minio_config.volumes_per_server}
      volumeClaimTemplate:
        metadata:
          name: data
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: ${var.minio_config.volume_size}
          storageClassName: managed-csi-premium
      resources:
        requests:
          cpu: "250m"
          memory: "512Mi"
        limits:
          cpu: "1"
          memory: "2Gi"
      securityContext:
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        runAsNonRoot: true
  mountPath: /data
  requestAutoCert: true
  configuration:
    name: minio-credentials
  users:
    - name: minio-postgres-credentials
  buckets:
    - name: postgres-backups
    - name: application-data
    - name: audit-logs
  features:
    enableSFTP: false
YAML
  }
}

# Job to apply the MinIO tenant
resource "kubernetes_job" "apply_minio_tenant" {
  depends_on = [
    helm_release.minio_operator,
    kubernetes_config_map.minio_tenant,
    kubernetes_secret.minio_credentials
  ]

  metadata {
    name      = "apply-minio-tenant"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }

  spec {
    ttl_seconds_after_finished = 300
    backoff_limit              = 3

    template {
      metadata {
        labels = {
          app = "minio-tenant-apply"
        }
      }

      spec {
        restart_policy       = "OnFailure"
        service_account_name = "default"

        container {
          name  = "kubectl"
          image = "bitnami/kubectl:latest"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOF
            set -e
            echo "Waiting for MinIO operator..."
            sleep 30
            echo "Applying MinIO tenant..."
            kubectl apply -f /config/tenant.yaml
            echo "MinIO tenant applied"
            EOF
          ]

          volume_mount {
            name       = "config"
            mount_path = "/config"
            read_only  = true
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.minio_tenant.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_completion = false
}

# -----------------------------------------------------------------------------
# Network Policies
# -----------------------------------------------------------------------------
resource "kubernetes_network_policy" "postgres" {
  metadata {
    name      = "postgres-access"
    namespace = kubernetes_namespace.postgres.metadata[0].name
  }

  spec {
    pod_selector {}

    ingress {
      from {
        namespace_selector {}
      }
      ports {
        port     = "5432"
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

resource "kubernetes_network_policy" "minio" {
  metadata {
    name      = "minio-access"
    namespace = kubernetes_namespace.minio.metadata[0].name
  }

  spec {
    pod_selector {}

    ingress {
      from {
        namespace_selector {}
      }
      ports {
        port     = "9000"
        protocol = "TCP"
      }
      ports {
        port     = "9001"
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
