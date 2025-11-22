# -----------------------------------------------------------------------------
# Automation Module Variables
# GitHub Actions Runner Controller
# -----------------------------------------------------------------------------

variable "chainguard_registry" {
  description = "Chainguard container registry base URL"
  type        = string
}

variable "postgres_host" {
  description = "PostgreSQL host"
  type        = string
}

variable "openbao_address" {
  description = "OpenBao address for secrets"
  type        = string
}

variable "actions_runner_version" {
  description = "GitHub Actions Runner Controller version"
  type        = string
  default     = "0.9.3"
}
