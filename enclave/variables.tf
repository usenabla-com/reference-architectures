# -----------------------------------------------------------------------------
# Global Configuration
# -----------------------------------------------------------------------------
variable "environment" {
  description = "Environment name (dev, staging, production, demo)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production", "demo"], var.environment)
    error_message = "Environment must be dev, staging, production, or demo."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus2"
}

variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "nabla"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy  = "terraform"
    Project    = "nabla-enclave"
    Compliance = "cmmc-level-2"
  }
}

# -----------------------------------------------------------------------------
# AKS Cluster Configuration
# -----------------------------------------------------------------------------
variable "kubernetes_version" {
  description = "Kubernetes version for AKS cluster"
  type        = string
  default     = "1.30"
}

variable "system_node_pool" {
  description = "System node pool configuration"
  type = object({
    vm_size    = string
    node_count = number
    min_count  = number
    max_count  = number
  })
  default = {
    vm_size    = "Standard_D4s_v3"
    node_count = 3
    min_count  = 3
    max_count  = 5
  }
}

variable "workload_node_pools" {
  description = "Additional workload node pools"
  type = map(object({
    vm_size      = string
    node_count   = number
    min_count    = number
    max_count    = number
    fips_enabled = bool
    taints       = list(string)
    labels       = map(string)
  }))
  default = {
    fips = {
      vm_size      = "Standard_D4s_v3"
      node_count   = 3
      min_count    = 3
      max_count    = 10
      fips_enabled = true
      taints       = []
      labels = {
        "usenabla.com/fips" = "true"
      }
    }
  }
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_prefixes" {
  description = "Subnet address prefixes"
  type = object({
    aks_nodes    = string
    aks_pods     = string
    private_link = string
    bastion      = string
  })
  default = {
    aks_nodes    = "10.0.0.0/22"
    aks_pods     = "10.0.16.0/20"
    private_link = "10.0.4.0/24"
    bastion      = "10.0.5.0/26"
  }
}

# -----------------------------------------------------------------------------
# Customer Domain Configuration
# -----------------------------------------------------------------------------
variable "domain" {
  description = "Customer's domain for the enclave (e.g., 'acmecorp.com')"
  type        = string
}

variable "cluster_prefix" {
  description = "Prefix for the Teleport cluster name (e.g., 'enclave' results in 'enclave.acmecorp.com')"
  type        = string
  default     = "enclave"
}

# -----------------------------------------------------------------------------
# Identity Configuration (Teleport)
# -----------------------------------------------------------------------------
variable "teleport_config" {
  description = "Teleport cluster configuration"
  type = object({
    acme_enabled  = bool
    acme_email    = string
    second_factor = string
  })
}

# -----------------------------------------------------------------------------
# Policy Configuration (OPAL + Cedar)
# -----------------------------------------------------------------------------
variable "opal_config" {
  description = "OPAL server configuration"
  type = object({
    policy_repo_url     = string
    policy_repo_branch  = string
    policy_repo_ssh_key = string
    replicas            = number
  })
  sensitive = true
}

# -----------------------------------------------------------------------------
# Secrets Management (OpenBao)
# -----------------------------------------------------------------------------
variable "openbao_config" {
  description = "OpenBao configuration"
  type = object({
    replicas      = number
    storage_size  = string
    audit_enabled = bool
  })
  default = {
    replicas      = 3
    storage_size  = "10Gi"
    audit_enabled = true
  }
}

# -----------------------------------------------------------------------------
# Data Tier Configuration (Operators only - customers provision their own DBs)
# -----------------------------------------------------------------------------
variable "postgres_config" {
  description = "CloudNative-PG operator configuration"
  type = object({
    instances     = number
    storage_size  = string
    storage_class = string
  })
  default = {
    instances     = 3
    storage_size  = "100Gi"
    storage_class = "managed-csi-premium"
  }
}

variable "minio_config" {
  description = "MinIO operator configuration"
  type = object({
    servers            = number
    volumes_per_server = number
    volume_size        = string
  })
  default = {
    servers            = 4
    volumes_per_server = 4
    volume_size        = "100Gi"
  }
}

# -----------------------------------------------------------------------------
# Chainguard Image Registry
# -----------------------------------------------------------------------------
variable "chainguard_registry" {
  description = "Chainguard container registry base URL"
  type        = string
  default     = "cgr.dev/chainguard"
}

# -----------------------------------------------------------------------------
# CUI Data Tier Configuration (Isolated from standard data)
# -----------------------------------------------------------------------------
variable "cui_enabled" {
  description = "Enable CUI-isolated data tier (PostgreSQL + MinIO)"
  type        = bool
  default     = true
}

variable "postgres_cui_config" {
  description = "CloudNative-PG configuration for CUI workloads"
  type = object({
    instances     = number
    storage_size  = string
    storage_class = string
  })
  default = {
    instances     = 3
    storage_size  = "100Gi"
    storage_class = "managed-csi-premium"
  }
}

variable "minio_cui_config" {
  description = "MinIO tenant configuration for CUI workloads"
  type = object({
    servers            = number
    volumes_per_server = number
    volume_size        = string
  })
  default = {
    servers            = 4
    volumes_per_server = 4
    volume_size        = "100Gi"
  }
}

