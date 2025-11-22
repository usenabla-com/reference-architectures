# -----------------------------------------------------------------------------
# Identity Module Outputs
# -----------------------------------------------------------------------------

output "teleport_proxy_address" {
  description = "Teleport proxy public address"
  value       = "https://${var.teleport_config.cluster_name}"
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

output "saml_acs_url" {
  description = "SAML Assertion Consumer Service URL for JumpCloud configuration"
  value       = "https://${var.teleport_config.cluster_name}/v1/webapi/saml/acs/jumpcloud"
}

output "saml_entity_id" {
  description = "SAML Entity ID for JumpCloud configuration"
  value       = "https://${var.teleport_config.cluster_name}"
}
