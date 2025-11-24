# -----------------------------------------------------------------------------
# Identity Module Variables
# Teleport Zero-Trust Access Configuration
# -----------------------------------------------------------------------------

variable "chainguard_registry" {
  description = "Chainguard container registry base URL"
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "teleport_cluster_fqdn" {
  description = "Fully qualified domain name for Teleport cluster (e.g., 'enclave.acmecorp.com')"
  type        = string
}

variable "teleport_config" {
  description = "Teleport cluster configuration"
  type = object({
    acme_enabled  = bool
    acme_email    = string
    second_factor = string
  })
}

variable "teleport_version" {
  description = "Teleport version to deploy"
  type        = string
  default     = "15.1.1"
}

variable "teleport_replicas" {
  description = "Number of Teleport auth/proxy replicas"
  type        = number
  default     = 3
}

variable "teleport_storage_size" {
  description = "Storage size for Teleport data"
  type        = string
  default     = "10Gi"
}

variable "teleport_session_ttl" {
  description = "Default session TTL"
  type        = string
  default     = "8h"
}

variable "teleport_operator_version" {
  description = "Teleport Kubernetes Operator version"
  type        = string
  default     = "15.1.1"
}
