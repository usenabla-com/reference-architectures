# -----------------------------------------------------------------------------
# Identity Module Outputs
# -----------------------------------------------------------------------------

output "teleport_proxy_address" {
  description = "Teleport proxy public address"
  value       = "https://${var.teleport_cluster_fqdn}"
}

output "teleport_auth_address" {
  description = "Teleport auth service internal address"
  value       = "teleport-auth.${kubernetes_namespace.teleport.metadata[0].name}.svc.cluster.local:3025"
}

output "teleport_namespace" {
  description = "Teleport Kubernetes namespace"
  value       = kubernetes_namespace.teleport.metadata[0].name
}

output "teleport_version" {
  description = "Deployed Teleport version"
  value       = helm_release.teleport.version
}

# -----------------------------------------------------------------------------
# Application Access URLs
# -----------------------------------------------------------------------------
output "app_urls" {
  description = "Application access URLs via Teleport"
  value = {
    code_server = "https://code.${var.teleport_cluster_fqdn}"
    mattermost  = "https://chat.${var.teleport_cluster_fqdn}"
    nextcloud   = "https://files.${var.teleport_cluster_fqdn}"
    grafana     = "https://grafana.${var.teleport_cluster_fqdn}"
    gatus       = "https://status.${var.teleport_cluster_fqdn}"
  }
}
