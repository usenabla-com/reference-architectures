variable "resource_group_name" {
  description = "Resource group name"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "system_node_pool" {
  description = "System node pool configuration"
  type = object({
    vm_size    = string
    node_count = number
    min_count  = number
    max_count  = number
  })
}

variable "workload_node_pools" {
  description = "Workload node pools configuration"
  type = map(object({
    vm_size      = string
    node_count   = number
    min_count    = number
    max_count    = number
    fips_enabled = bool
    taints       = list(string)
    labels       = map(string)
  }))
}

variable "vnet_address_space" {
  description = "VNet address space"
  type        = list(string)
}

variable "subnet_prefixes" {
  description = "Subnet address prefixes"
  type = object({
    aks_nodes    = string
    aks_pods     = string
    private_link = string
    bastion      = string
  })
}
