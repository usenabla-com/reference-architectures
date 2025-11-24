# -----------------------------------------------------------------------------
# Network Module
# Cilium CNI with Hubble Observability
# Zero-Trust Network Security for AKS
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }
}

# -----------------------------------------------------------------------------
# Cilium CNI via Helm
# -----------------------------------------------------------------------------
resource "helm_release" "cilium" {
  name             = "cilium"
  repository       = "https://helm.cilium.io"
  chart            = "cilium"
  version          = var.cilium_version
  namespace        = "kube-system"
  create_namespace = false
  wait             = true
  timeout          = 600

  values = [yamlencode({
    aksbyocni = {
      enabled = true
    }
    nodeinit = {
      enabled = true
    }
    ipam = {
      mode = var.cilium_config.ipam_mode
      operator = {
        clusterPoolIPv4PodCIDRList = [var.cilium_config.cluster_pool_ipv4_cidr]
      }
    }
    tunnel = var.cilium_config.tunnel_mode
    hubble = {
      enabled = var.cilium_config.enable_hubble
      relay = {
        enabled = var.cilium_config.enable_hubble_relay
      }
      ui = {
        enabled = var.cilium_config.enable_hubble_ui
      }
      metrics = {
        enabled = ["dns", "drop", "tcp", "flow", "icmp", "http"]
      }
    }
    bandwidthManager = {
      enabled = var.cilium_config.enable_bandwidth_mgr
    }
    hostFirewall = {
      enabled = var.cilium_config.enable_host_firewall
    }
    nodePort = {
      enabled = var.cilium_config.enable_node_port
    }
    encryption = {
      enabled = var.cilium_config.enable_wireguard
      type    = "wireguard"
    }
    operator = {
      replicas = 2
    }
    policyEnforcementMode = "default"
    bpf = {
      masquerade         = true
      monitorAggregation = "medium"
    }
    securityContext = {
      capabilities = {
        ciliumAgent      = ["CHOWN", "KILL", "NET_ADMIN", "NET_RAW", "IPC_LOCK", "SYS_ADMIN", "SYS_RESOURCE", "DAC_OVERRIDE", "FOWNER", "SETGID", "SETUID"]
        cleanCiliumState = ["NET_ADMIN", "SYS_ADMIN", "SYS_RESOURCE"]
      }
    }
    prometheus = {
      enabled = true
      serviceMonitor = {
        enabled = true
      }
    }
    resources = {
      limits = {
        cpu    = "1000m"
        memory = "1Gi"
      }
      requests = {
        cpu    = "100m"
        memory = "512Mi"
      }
    }
  })]
}

# -----------------------------------------------------------------------------
# Default Network Policies (Zero Trust)
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "default_deny_all" {
  depends_on = [helm_release.cilium]

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumClusterwideNetworkPolicy
    metadata:
      name: default-deny-all
    spec:
      description: "Default deny all traffic for zero-trust"
      endpointSelector: {}
      ingress:
        - fromEndpoints:
            - {}
      egress:
        - toEndpoints:
            - {}
        - toEntities:
            - kube-apiserver
        - toPorts:
            - ports:
                - port: "53"
                  protocol: UDP
              rules:
                dns:
                  - matchPattern: "*"
  YAML
}

# Allow kube-system namespace full access
resource "kubectl_manifest" "allow_kube_system" {
  depends_on = [helm_release.cilium]

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumClusterwideNetworkPolicy
    metadata:
      name: allow-kube-system
    spec:
      description: "Allow kube-system namespace traffic"
      endpointSelector:
        matchLabels:
          "k8s:io.kubernetes.pod.namespace": kube-system
      ingress:
        - fromEntities:
            - cluster
            - host
      egress:
        - toEntities:
            - cluster
            - host
            - world
  YAML
}

# Allow DNS resolution cluster-wide
resource "kubectl_manifest" "allow_dns" {
  depends_on = [helm_release.cilium]

  yaml_body = <<-YAML
    apiVersion: cilium.io/v2
    kind: CiliumClusterwideNetworkPolicy
    metadata:
      name: allow-dns
    spec:
      description: "Allow DNS resolution"
      endpointSelector: {}
      egress:
        - toEndpoints:
            - matchLabels:
                "k8s:io.kubernetes.pod.namespace": kube-system
                k8s-app: kube-dns
          toPorts:
            - ports:
                - port: "53"
                  protocol: UDP
                - port: "53"
                  protocol: TCP
  YAML
}
