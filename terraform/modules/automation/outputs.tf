# -----------------------------------------------------------------------------
# Automation Module Outputs
# -----------------------------------------------------------------------------

output "namespace" {
  description = "Automation namespace"
  value       = kubernetes_namespace.automation.metadata[0].name
}

output "github_auth_secret" {
  description = "GitHub auth secret name (must be populated manually)"
  value       = kubernetes_secret.github_auth.metadata[0].name
}
