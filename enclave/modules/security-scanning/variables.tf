# -----------------------------------------------------------------------------
# Security Scanning Module Variables
# Grype Container Vulnerability Scanning
# -----------------------------------------------------------------------------

variable "chainguard_registry" {
  description = "Chainguard container registry base URL"
  type        = string
}

variable "grype_version" {
  description = "Grype image version"
  type        = string
  default     = "v0.74.0"
}

variable "scan_schedule" {
  description = "Cron schedule for vulnerability scans"
  type        = string
  default     = "0 2 * * *" # Daily at 2 AM
}
