# -----------------------------------------------------------------------------
# Policy Module Variables
# OPAL + Cedar Policy Engine Configuration
# -----------------------------------------------------------------------------

variable "chainguard_registry" {
  description = "Chainguard container registry base URL"
  type        = string
}

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

variable "teleport_auth_url" {
  description = "Teleport auth service URL for identity integration"
  type        = string
}

variable "opal_version" {
  description = "OPAL server image tag"
  type        = string
  default     = "0.7.5"
}

variable "cedar_agent_version" {
  description = "Cedar authorization agent version"
  type        = string
  default     = "latest"
}
