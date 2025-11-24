# -----------------------------------------------------------------------------
# Provisioning Module Outputs
# -----------------------------------------------------------------------------

output "namespace" {
  description = "Platform namespace name"
  value       = kubernetes_namespace.nabla_system.metadata[0].name
}

output "workloads_namespace" {
  description = "Standard workloads namespace"
  value       = kubernetes_namespace.workloads.metadata[0].name
}

output "workloads_cui_namespace" {
  description = "CUI workloads namespace (if enabled)"
  value       = var.cui_enabled ? kubernetes_namespace.workloads_cui[0].metadata[0].name : null
}
