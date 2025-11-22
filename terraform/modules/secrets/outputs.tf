# -----------------------------------------------------------------------------
# Secrets Module Outputs
# -----------------------------------------------------------------------------

output "openbao_address" {
  description = "OpenBao service address"
  value       = "http://openbao.${kubernetes_namespace.openbao.metadata[0].name}.svc.cluster.local:8200"
}

output "openbao_namespace" {
  description = "OpenBao Kubernetes namespace"
  value       = kubernetes_namespace.openbao.metadata[0].name
}

output "openbao_service_name" {
  description = "OpenBao service name"
  value       = "openbao"
}

output "openbao_ui_address" {
  description = "OpenBao UI service address"
  value       = "http://openbao-ui.${kubernetes_namespace.openbao.metadata[0].name}.svc.cluster.local:8200"
}
