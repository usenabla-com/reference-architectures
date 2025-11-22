# -----------------------------------------------------------------------------
# Network Module Outputs
# -----------------------------------------------------------------------------

output "cilium_version" {
  description = "Deployed Cilium version"
  value       = helm_release.cilium.version
}

output "cilium_status" {
  description = "Cilium Helm release status"
  value       = helm_release.cilium.status
}

output "hubble_enabled" {
  description = "Whether Hubble observability is enabled"
  value       = var.cilium_config.enable_hubble
}

output "hubble_ui_enabled" {
  description = "Whether Hubble UI is enabled"
  value       = var.cilium_config.enable_hubble_ui
}
