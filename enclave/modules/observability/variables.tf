# -----------------------------------------------------------------------------
# Observability Module Variables
# Prometheus + Gatus Configuration
# -----------------------------------------------------------------------------

variable "chainguard_registry" {
  description = "Chainguard container registry base URL"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "prometheus_version" {
  description = "Prometheus stack Helm chart version"
  type        = string
  default     = "56.6.2"
}

variable "gatus_version" {
  description = "Gatus Helm chart version"
  type        = string
  default     = "3.4.1"
}

variable "retention_days" {
  description = "Metrics retention period in days"
  type        = number
  default     = 30
}
