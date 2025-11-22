# -----------------------------------------------------------------------------
# Global Configuration
# -----------------------------------------------------------------------------
variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
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
  default     = "1.29"
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
        "enclave.nabla.io/fips" = "true"
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
# Identity Configuration (Teleport + JumpCloud)
# -----------------------------------------------------------------------------
variable "teleport_config" {
  description = "Teleport cluster configuration"
  type = object({
    cluster_name  = string
    acme_enabled  = bool
    acme_email    = string
    second_factor = string
  })
  default = {
    cluster_name  = "enclave.nabla.io"
    acme_enabled  = true
    acme_email    = "admin@nabla.io"
    second_factor = "webauthn"
  }
}

variable "jumpcloud_config" {
  description = "JumpCloud SAML IdP configuration"
  type = object({
    org_id             = string
    saml_entity_id     = string
    saml_sso_url       = string
    saml_certificate   = string
    attribute_mappings = map(string)
  })
  sensitive = true
}

# -----------------------------------------------------------------------------
# Policy Configuration (OPAL + Cedar)
# -----------------------------------------------------------------------------
variable "opal_config" {
  description = "OPAL server configuration"
  type = object({
    policy_repo_url    = string
    policy_repo_branch = string
    policy_repo_ssh_key = string
    replicas           = number
  })
  sensitive = true
  default = {
    policy_repo_url     = ""
    policy_repo_branch  = "main"
    policy_repo_ssh_key = ""
    replicas            = 2
  }
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
# Data Tier Configuration
# -----------------------------------------------------------------------------
variable "postgres_config" {
  description = "CloudNative-PG configuration"
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
  description = "MinIO tenant configuration"
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
