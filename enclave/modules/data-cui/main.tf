# -----------------------------------------------------------------------------
# Data CUI Module
# Isolated CloudNative-PG PostgreSQL + MinIO for CUI Workloads
# CMMC SC.L2-3.13.16 - Data at Rest Protection (CUI-specific)
# Completely isolated from standard data tier per CMMC requirements
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CUI Namespaces - Isolated from standard namespaces
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "postgres_cui" {
  metadata {
    name = "postgres-cui"
    labels = {
      "app.kubernetes.io/name"             = "postgres-cui"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "usenabla.com/data-classification"   = "cui"
      "usenabla.com/isolation-boundary"    = "cui"
    }
  }
}

resource "kubernetes_namespace" "minio_cui" {
  metadata {
    name = "minio-cui"
    labels = {
      "app.kubernetes.io/name"             = "minio-cui"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
      "usenabla.com/data-classification"   = "cui"
      "usenabla.com/isolation-boundary"    = "cui"
    }
  }
}

# -----------------------------------------------------------------------------
# CUI PostgreSQL Cluster Configuration
# Uses the CNPG operator deployed by the standard data module
# -----------------------------------------------------------------------------
resource "kubernetes_secret" "postgres_cui_credentials" {
  metadata {
    name      = "postgres-cui-superuser"
    namespace = kubernetes_namespace.postgres_cui.metadata[0].name
  }

  data = {
    username = "postgres"
    password = random_password.postgres_cui_password.result
  }

  type = "kubernetes.io/basic-auth"
}

resource "random_password" "postgres_cui_password" {
  length  = 32
  special = false
}

resource "kubernetes_config_map" "cnpg_cui_cluster" {
  metadata {
    name      = "enclave-postgres-cui-cluster"
    namespace = kubernetes_namespace.postgres_cui.metadata[0].name
  }

  data = {
    "cluster.yaml" = <<-YAML
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: enclave-postgres-cui
  namespace: ${kubernetes_namespace.postgres_cui.metadata[0].name}
  labels:
    usenabla.com/data-classification: cui
spec:
  instances: ${var.postgres_cui_config.instances}
  primaryUpdateStrategy: unsupervised

  storage:
    size: ${var.postgres_cui_config.storage_size}
    storageClass: ${var.postgres_cui_config.storage_class}

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
      # Enhanced security settings for CUI
      ssl: "on"
      ssl_min_protocol_version: "TLSv1.3"
      password_encryption: "scram-sha-256"
      log_connections: "on"
      log_disconnections: "on"
      log_statement: "all"  # Full audit logging for CUI
      log_duration: "on"
    pg_hba:
      # CUI cluster only accepts connections from CUI namespaces
      - hostssl all all 0.0.0.0/0 scram-sha-256

  bootstrap:
    initdb:
      database: enclave_cui
      owner: enclave_cui
      secret:
        name: postgres-cui-superuser

  superuserSecret:
    name: postgres-cui-superuser

  monitoring:
    enablePodMonitor: true

  backup:
    barmanObjectStore:
      destinationPath: s3://postgres-cui-backups/
      endpointURL: http://minio-cui.minio-cui.svc.cluster.local:9000
      s3Credentials:
        accessKeyId:
          name: minio-postgres-cui-credentials
          key: accesskey
        secretAccessKey:
          name: minio-postgres-cui-credentials
          key: secretkey
      wal:
        compression: gzip
        encryption: AES256
      data:
        compression: gzip
        encryption: AES256
    retentionPolicy: "90d"  # Longer retention for CUI compliance

  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2"
      memory: "4Gi"

  affinity:
    podAntiAffinityType: required
    # CUI workloads on FIPS-enabled nodes
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: usenabla.com/fips
                operator: In
                values:
                  - "true"
YAML
  }
}

# Job to apply the CUI CNPG cluster
resource "kubernetes_job" "apply_cnpg_cui_cluster" {
  depends_on = [
    kubernetes_config_map.cnpg_cui_cluster,
    kubernetes_secret.postgres_cui_credentials
  ]

  metadata {
    name      = "apply-cnpg-cui-cluster"
    namespace = kubernetes_namespace.postgres_cui.metadata[0].name
  }

  spec {
    ttl_seconds_after_finished = 300
    backoff_limit              = 3

    template {
      metadata {
        labels = {
          app = "cnpg-cui-cluster-apply"
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
            echo "Applying CUI PostgreSQL cluster..."
            kubectl apply -f /config/cluster.yaml
            echo "CUI PostgreSQL cluster applied"
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
            name = kubernetes_config_map.cnpg_cui_cluster.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_completion = false
}

# -----------------------------------------------------------------------------
# CUI MinIO Tenant Configuration
# Isolated object storage for CUI data
# -----------------------------------------------------------------------------
resource "random_password" "minio_cui_root_password" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "minio_cui_credentials" {
  metadata {
    name      = "minio-cui-credentials"
    namespace = kubernetes_namespace.minio_cui.metadata[0].name
  }

  data = {
    accesskey = "enclave-cui-admin"
    secretkey = random_password.minio_cui_root_password.result
  }

  type = "Opaque"
}

# MinIO credentials for CUI PostgreSQL backups
resource "kubernetes_secret" "minio_postgres_cui_credentials" {
  metadata {
    name      = "minio-postgres-cui-credentials"
    namespace = kubernetes_namespace.postgres_cui.metadata[0].name
  }

  data = {
    accesskey = "postgres-cui-backup"
    secretkey = random_password.minio_postgres_cui_password.result
  }

  type = "Opaque"
}

resource "random_password" "minio_postgres_cui_password" {
  length  = 32
  special = false
}

resource "kubernetes_config_map" "minio_cui_tenant" {
  metadata {
    name      = "minio-cui-tenant-config"
    namespace = kubernetes_namespace.minio_cui.metadata[0].name
  }

  data = {
    "tenant.yaml" = <<-YAML
apiVersion: minio.min.io/v2
kind: Tenant
metadata:
  name: enclave-minio-cui
  namespace: ${kubernetes_namespace.minio_cui.metadata[0].name}
  labels:
    usenabla.com/data-classification: cui
spec:
  image: minio/minio:RELEASE.2024-01-16T16-07-38Z
  pools:
    - servers: ${var.minio_cui_config.servers}
      volumesPerServer: ${var.minio_cui_config.volumes_per_server}
      volumeClaimTemplate:
        metadata:
          name: data
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: ${var.minio_cui_config.volume_size}
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
      # CUI workloads on FIPS-enabled nodes
      nodeSelector:
        usenabla.com/fips: "true"
  mountPath: /data
  requestAutoCert: true
  configuration:
    name: minio-cui-credentials
  users:
    - name: minio-postgres-cui-credentials
  buckets:
    - name: postgres-cui-backups
    - name: cui-application-data
    - name: cui-audit-logs
  features:
    enableSFTP: false
YAML
  }
}

# Job to apply the CUI MinIO tenant
resource "kubernetes_job" "apply_minio_cui_tenant" {
  depends_on = [
    kubernetes_config_map.minio_cui_tenant,
    kubernetes_secret.minio_cui_credentials
  ]

  metadata {
    name      = "apply-minio-cui-tenant"
    namespace = kubernetes_namespace.minio_cui.metadata[0].name
  }

  spec {
    ttl_seconds_after_finished = 300
    backoff_limit              = 3

    template {
      metadata {
        labels = {
          app = "minio-cui-tenant-apply"
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
            echo "Applying CUI MinIO tenant..."
            kubectl apply -f /config/tenant.yaml
            echo "CUI MinIO tenant applied"
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
            name = kubernetes_config_map.minio_cui_tenant.metadata[0].name
          }
        }
      }
    }
  }

  wait_for_completion = false
}

# -----------------------------------------------------------------------------
# CUI Network Policies - Strict isolation
# Only CUI-labeled namespaces can access CUI data
# -----------------------------------------------------------------------------
resource "kubernetes_network_policy" "postgres_cui" {
  metadata {
    name      = "postgres-cui-access"
    namespace = kubernetes_namespace.postgres_cui.metadata[0].name
  }

  spec {
    pod_selector {}

    # Only allow ingress from CUI-labeled namespaces
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "usenabla.com/isolation-boundary" = "cui"
          }
        }
      }
      ports {
        port     = "5432"
        protocol = "TCP"
      }
    }

    # Egress only to CUI MinIO for backups
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

resource "kubernetes_network_policy" "minio_cui" {
  metadata {
    name      = "minio-cui-access"
    namespace = kubernetes_namespace.minio_cui.metadata[0].name
  }

  spec {
    pod_selector {}

    # Only allow ingress from CUI-labeled namespaces
    ingress {
      from {
        namespace_selector {
          match_labels = {
            "usenabla.com/isolation-boundary" = "cui"
          }
        }
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

    # Egress only within CUI boundary
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
