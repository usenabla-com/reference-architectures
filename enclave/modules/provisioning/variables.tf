# -----------------------------------------------------------------------------
# Provisioning Module Variables
# -----------------------------------------------------------------------------

variable "namespace" {
  description = "Kubernetes namespace for platform resources"
  type        = string
  default     = "nabla-system"
}

variable "cui_enabled" {
  description = "Enable CUI workloads namespace"
  type        = bool
  default     = true
}
