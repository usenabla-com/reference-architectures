# -----------------------------------------------------------------------------
# Workloads Module Outputs
# -----------------------------------------------------------------------------

output "code_server_url" {
  description = "Code-Server URL"
  value       = "http://code-server.${kubernetes_namespace.workloads.metadata[0].name}.svc.cluster.local:8080"
}

output "open_webui_url" {
  description = "Open-WebUI URL"
  value       = "http://open-webui.${kubernetes_namespace.workloads.metadata[0].name}.svc.cluster.local:8080"
}

output "mattermost_url" {
  description = "Mattermost URL"
  value       = "http://mattermost.${kubernetes_namespace.workloads.metadata[0].name}.svc.cluster.local:8065"
}

output "nextcloud_url" {
  description = "Nextcloud URL"
  value       = "http://nextcloud.${kubernetes_namespace.workloads.metadata[0].name}.svc.cluster.local:80"
}

output "namespace" {
  description = "Workloads namespace"
  value       = kubernetes_namespace.workloads.metadata[0].name
}
