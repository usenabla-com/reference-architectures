# -----------------------------------------------------------------------------
# Security Scanning Module Outputs
# -----------------------------------------------------------------------------

output "namespace" {
  description = "Security scanning namespace"
  value       = kubernetes_namespace.security_scanning.metadata[0].name
}

output "scanner_service_account" {
  description = "Grype scanner service account"
  value       = kubernetes_service_account.grype_scanner.metadata[0].name
}

output "scan_schedule" {
  description = "Vulnerability scan schedule"
  value       = var.scan_schedule
}
