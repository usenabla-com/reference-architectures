# -----------------------------------------------------------------------------
# Secrets Module Variables
# OpenBao Configuration
# -----------------------------------------------------------------------------

variable "chainguard_registry" {
  description = "Chainguard container registry base URL"
  type        = string
}

variable "openbao_config" {
  description = "OpenBao configuration"
  type = object({
    replicas      = number
    storage_size  = string
    audit_enabled = bool
  })
}

variable "key_vault_id" {
  description = "Azure Key Vault ID for auto-unseal"
  type        = string
}

variable "openbao_version" {
  description = "OpenBao Helm chart version"
  type        = string
  default     = "0.4.0"
}
