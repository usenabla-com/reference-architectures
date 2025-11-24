# -----------------------------------------------------------------------------
# Security Scanning Module
# Grype Container Vulnerability Scanner
# CMMC RA.L2-3.11.2 - Vulnerability Scanning
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Namespace
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "security_scanning" {
  metadata {
    name = "security-scanning"
    labels = {
      "app.kubernetes.io/name"             = "security-scanning"
      "app.kubernetes.io/managed-by"       = "terraform"
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# -----------------------------------------------------------------------------
# Grype Configuration
# -----------------------------------------------------------------------------
resource "kubernetes_config_map" "grype_config" {
  metadata {
    name      = "grype-config"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
  }

  data = {
    ".grype.yaml" = <<-YAML
check-for-app-update: false
fail-on-severity: high
output: json
quiet: false
add-cpes-if-none: true
db:
  auto-update: true
  cache-dir: /tmp/grype-db
YAML

    "scan-namespaces.sh" = <<-BASH
#!/bin/bash
set -e

NAMESPACES="teleport openbao policy-system postgres minio observability workloads automation"
REPORT_DIR="/reports"
DATE=$(date +%Y-%m-%d)

mkdir -p "$REPORT_DIR/$DATE"

for ns in $NAMESPACES; do
  echo "Scanning namespace: $ns"

  # Get all images in namespace
  IMAGES=$(kubectl get pods -n "$ns" -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' 2>/dev/null | sort -u)

  for image in $IMAGES; do
    if [ -n "$image" ]; then
      SAFE_IMAGE=$(echo "$image" | tr '/:' '_')
      echo "Scanning image: $image"
      grype "$image" -o json > "$REPORT_DIR/$DATE/$ns-$SAFE_IMAGE.json" 2>&1 || true
    fi
  done
done

echo "Scan complete. Reports saved to $REPORT_DIR/$DATE"

# Generate summary
echo "=== Vulnerability Summary ===" > "$REPORT_DIR/$DATE/summary.txt"
for report in "$REPORT_DIR/$DATE"/*.json; do
  if [ -f "$report" ]; then
    CRITICAL=$(jq '[.matches[] | select(.vulnerability.severity == "Critical")] | length' "$report" 2>/dev/null || echo 0)
    HIGH=$(jq '[.matches[] | select(.vulnerability.severity == "High")] | length' "$report" 2>/dev/null || echo 0)
    echo "$(basename $report): Critical=$CRITICAL, High=$HIGH" >> "$REPORT_DIR/$DATE/summary.txt"
  fi
done

cat "$REPORT_DIR/$DATE/summary.txt"
BASH
  }
}

# -----------------------------------------------------------------------------
# Grype Scanner CronJob
# -----------------------------------------------------------------------------
resource "kubernetes_cron_job_v1" "grype_scanner" {
  metadata {
    name      = "grype-vulnerability-scanner"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "grype-scanner"
      "app.kubernetes.io/component" = "security"
    }
  }

  spec {
    schedule                      = var.scan_schedule
    concurrency_policy            = "Forbid"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 3

    job_template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "grype-scanner"
        }
      }

      spec {
        ttl_seconds_after_finished = 86400 # Keep for 1 day
        backoff_limit              = 2

        template {
          metadata {
            labels = {
              "app.kubernetes.io/name" = "grype-scanner"
            }
          }

          spec {
            restart_policy       = "OnFailure"
            service_account_name = kubernetes_service_account.grype_scanner.metadata[0].name

            security_context {
              run_as_non_root = true
              run_as_user     = 65532
              fs_group        = 65532
            }

            container {
              name  = "grype"
              image = "anchore/grype:${var.grype_version}"

              command = ["/bin/sh", "-c"]
              args = [
                <<-EOF
                cp /config/.grype.yaml /tmp/.grype.yaml
                chmod +x /scripts/scan-namespaces.sh
                /scripts/scan-namespaces.sh
                EOF
              ]

              env {
                name  = "GRYPE_DB_CACHE_DIR"
                value = "/tmp/grype-db"
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

              security_context {
                allow_privilege_escalation = false
                read_only_root_filesystem  = false
                run_as_non_root            = true
                capabilities {
                  drop = ["ALL"]
                }
              }

              volume_mount {
                name       = "config"
                mount_path = "/config"
                read_only  = true
              }

              volume_mount {
                name       = "scripts"
                mount_path = "/scripts"
                read_only  = true
              }

              volume_mount {
                name       = "reports"
                mount_path = "/reports"
              }

              volume_mount {
                name       = "tmp"
                mount_path = "/tmp"
              }
            }

            volume {
              name = "config"
              config_map {
                name = kubernetes_config_map.grype_config.metadata[0].name
                items {
                  key  = ".grype.yaml"
                  path = ".grype.yaml"
                }
              }
            }

            volume {
              name = "scripts"
              config_map {
                name         = kubernetes_config_map.grype_config.metadata[0].name
                default_mode = "0755"
                items {
                  key  = "scan-namespaces.sh"
                  path = "scan-namespaces.sh"
                }
              }
            }

            volume {
              name = "reports"
              empty_dir {}
            }

            volume {
              name = "tmp"
              empty_dir {}
            }
          }
        }
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Service Account with permissions to list pods
# -----------------------------------------------------------------------------
resource "kubernetes_service_account" "grype_scanner" {
  metadata {
    name      = "grype-scanner"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
  }
}

resource "kubernetes_cluster_role" "grype_scanner" {
  metadata {
    name = "grype-scanner"
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "grype_scanner" {
  metadata {
    name = "grype-scanner"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.grype_scanner.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.grype_scanner.metadata[0].name
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
  }
}

# -----------------------------------------------------------------------------
# Network Policy
# -----------------------------------------------------------------------------
resource "kubernetes_network_policy" "security_scanning" {
  metadata {
    name      = "security-scanning-access"
    namespace = kubernetes_namespace.security_scanning.metadata[0].name
  }

  spec {
    pod_selector {}

    egress {
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
    }

    policy_types = ["Egress"]
  }
}
