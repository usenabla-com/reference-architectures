# -----------------------------------------------------------------------------
# Secrets Module
# OpenBao Secrets Management
# CMMC SC.L2-3.13.10 - Cryptographic key management
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Namespace for Secrets Management
# -----------------------------------------------------------------------------
resource "kubernetes_namespace" "openbao" {
  metadata {
    name = "openbao"
    labels = {
      "app.kubernetes.io/name"              = "openbao"
      "app.kubernetes.io/managed-by"        = "terraform"
      "pod-security.kubernetes.io/enforce"  = "restricted"
    }
  }
}

# -----------------------------------------------------------------------------
# OpenBao Helm Release
# -----------------------------------------------------------------------------
resource "helm_release" "openbao" {
  name             = "openbao"
  repository       = "https://openbao.github.io/openbao-helm"
  chart            = "openbao"
  version          = var.openbao_version
  namespace        = kubernetes_namespace.openbao.metadata[0].name
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [yamlencode({
    global = {
      enabled = true
    }
    injector = {
      enabled = true
      replicas = 2
      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }
    }
    server = {
      enabled = true
      image = {
        repository = "quay.io/openbao/openbao"
        tag        = "2.0.0"
      }
      updateStrategyType = "RollingUpdate"
      resources = {
        requests = {
          cpu    = "250m"
          memory = "256Mi"
        }
        limits = {
          cpu    = "1000m"
          memory = "1Gi"
        }
      }
      readinessProbe = {
        enabled = true
        path    = "/v1/sys/health?standbyok=true"
      }
      livenessProbe = {
        enabled     = true
        path        = "/v1/sys/health?standbyok=true"
        initialDelaySeconds = 60
      }
      auditStorage = {
        enabled      = var.openbao_config.audit_enabled
        size         = "10Gi"
        storageClass = "managed-csi-premium"
      }
      dataStorage = {
        enabled      = true
        size         = var.openbao_config.storage_size
        storageClass = "managed-csi-premium"
      }
      ha = {
        enabled  = true
        replicas = var.openbao_config.replicas
        raft = {
          enabled   = true
          setNodeId = true
          config = <<-EOF
            ui = true

            listener "tcp" {
              tls_disable = 1
              address = "[::]:8200"
              cluster_address = "[::]:8201"
            }

            storage "raft" {
              path = "/openbao/data"
              retry_join {
                leader_api_addr = "http://openbao-0.openbao-internal:8200"
              }
              retry_join {
                leader_api_addr = "http://openbao-1.openbao-internal:8200"
              }
              retry_join {
                leader_api_addr = "http://openbao-2.openbao-internal:8200"
              }
            }

            service_registration "kubernetes" {}

            seal "azurekeyvault" {
              tenant_id      = "$${AZURE_TENANT_ID}"
              vault_name     = "$${AZURE_VAULT_NAME}"
              key_name       = "openbao-unseal"
            }
          EOF
        }
      }
      service = {
        enabled = true
        type    = "ClusterIP"
      }
      serviceAccount = {
        create = true
        annotations = {
          "azure.workload.identity/client-id" = "$${AZURE_CLIENT_ID}"
        }
      }
      extraEnvironmentVars = {
        AZURE_TENANT_ID  = "$${AZURE_TENANT_ID}"
        AZURE_CLIENT_ID  = "$${AZURE_CLIENT_ID}"
        AZURE_VAULT_NAME = "$${AZURE_VAULT_NAME}"
      }
    }
    ui = {
      enabled         = true
      serviceType     = "ClusterIP"
      serviceNodePort = null
    }
    csi = {
      enabled = true
      resources = {
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "250m"
          memory = "256Mi"
        }
      }
    }
  })]
}

# -----------------------------------------------------------------------------
# OpenBao Network Policy
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "openbao_network_policy" {
  depends_on = [helm_release.openbao]

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: openbao-access
      namespace: ${kubernetes_namespace.openbao.metadata[0].name}
    spec:
      endpointSelector:
        matchLabels:
          app.kubernetes.io/name: openbao
      ingress:
        - fromEndpoints:
            - matchLabels:
                "k8s:io.kubernetes.pod.namespace": kube-system
        - fromEndpoints:
            - {}
          toPorts:
            - ports:
                - port: "8200"
                  protocol: TCP
                - port: "8201"
                  protocol: TCP
      egress:
        - toEntities:
            - cluster
        - toFQDNs:
            - matchPattern: "*.vault.azure.net"
          toPorts:
            - ports:
                - port: "443"
                  protocol: TCP
  YAML
}

# -----------------------------------------------------------------------------
# OpenBao PKI Secrets Engine Configuration (post-init)
# These resources should be applied after OpenBao is initialized and unsealed
# -----------------------------------------------------------------------------

# Note: The following resources require OpenBao to be initialized first.
# They are included as reference for manual configuration or a separate
# initialization workflow.

# resource "kubectl_manifest" "openbao_pki_policy" {
#   yaml_body = <<-YAML
#     apiVersion: v1
#     kind: ConfigMap
#     metadata:
#       name: openbao-pki-config
#       namespace: ${kubernetes_namespace.openbao.metadata[0].name}
#     data:
#       pki-policy.hcl: |
#         path "pki/*" {
#           capabilities = ["create", "read", "update", "delete", "list"]
#         }
#         path "pki_int/*" {
#           capabilities = ["create", "read", "update", "delete", "list"]
#         }
#   YAML
# }
