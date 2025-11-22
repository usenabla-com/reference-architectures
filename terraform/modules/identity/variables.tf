# -----------------------------------------------------------------------------
# Identity Module Variables
# Teleport + JumpCloud SAML SSO Configuration
# -----------------------------------------------------------------------------

variable "chainguard_registry" {
  description = "Chainguard container registry base URL"
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name"
  type        = string
}

variable "teleport_config" {
  description = "Teleport cluster configuration"
  type = object({
    cluster_name  = string
    acme_enabled  = bool
    acme_email    = string
    second_factor = string
  })
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
