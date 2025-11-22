# -----------------------------------------------------------------------------
# Network Module Variables
# Cilium CNI Configuration
# -----------------------------------------------------------------------------

variable "chainguard_registry" {
  description = "Chainguard container registry base URL"
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name for identification"
  type        = string
}

variable "cilium_version" {
  description = "Cilium version to deploy"
  type        = string
  default     = "1.15.1"
}

variable "cilium_config" {
  description = "Cilium CNI configuration options"
  type = object({
    tunnel_mode           = string
    enable_hubble         = bool
    enable_hubble_relay   = bool
    enable_hubble_ui      = bool
    enable_bandwidth_mgr  = bool
    enable_host_firewall  = bool
    enable_node_port      = bool
    enable_wireguard      = bool
    ipam_mode             = string
    cluster_pool_ipv4_cidr = string
  })
  default = {
    tunnel_mode            = "vxlan"
    enable_hubble          = true
    enable_hubble_relay    = true
    enable_hubble_ui       = true
    enable_bandwidth_mgr   = true
    enable_host_firewall   = true
    enable_node_port       = true
    enable_wireguard       = false # Enable for additional encryption
    ipam_mode              = "cluster-pool"
    cluster_pool_ipv4_cidr = "10.0.16.0/20"
  }
}
