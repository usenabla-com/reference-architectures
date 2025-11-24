# -----------------------------------------------------------------------------
# Nabla Enclave - Outputs
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Cluster Outputs
# -----------------------------------------------------------------------------
output "cluster_name" {
  description = "AKS cluster name"
  value       = module.cluster.cluster_name
}

output "cluster_fqdn" {
  description = "AKS cluster FQDN"
  value       = module.cluster.cluster_fqdn
}

output "cluster_identity" {
  description = "AKS cluster managed identity"
  value       = module.cluster.cluster_identity
}

output "kubeconfig_command" {
  description = "Command to get kubeconfig"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.enclave.name} --name ${module.cluster.cluster_name}"
}

# -----------------------------------------------------------------------------
# Identity Outputs (Teleport)
# -----------------------------------------------------------------------------
output "teleport_proxy_url" {
  description = "Teleport proxy public URL"
  value       = module.identity.teleport_proxy_address
}

output "teleport_auth_url" {
  description = "Teleport auth service internal URL"
  value       = module.identity.teleport_auth_address
}

# -----------------------------------------------------------------------------
# Secrets Outputs (OpenBao)
# -----------------------------------------------------------------------------
output "openbao_address" {
  description = "OpenBao cluster address"
  value       = module.secrets.openbao_address
}

# -----------------------------------------------------------------------------
# Data Tier Outputs (Operators - customers use these to provision DBs)
# -----------------------------------------------------------------------------
output "postgres_rw_service" {
  description = "PostgreSQL read-write service endpoint"
  value       = module.data.postgres_rw_service
}

output "postgres_ro_service" {
  description = "PostgreSQL read-only service endpoint"
  value       = module.data.postgres_ro_service
}

output "minio_endpoint" {
  description = "MinIO S3 endpoint"
  value       = module.data.minio_endpoint
}

output "minio_console_url" {
  description = "MinIO console URL"
  value       = module.data.minio_console_url
}

# -----------------------------------------------------------------------------
# Observability Outputs
# -----------------------------------------------------------------------------
output "grafana_url" {
  description = "Grafana dashboard URL (internal)"
  value       = module.observability.grafana_url
}

output "prometheus_url" {
  description = "Prometheus URL (internal)"
  value       = module.observability.prometheus_url
}

# -----------------------------------------------------------------------------
# Policy Outputs
# -----------------------------------------------------------------------------
output "cedar_pdp_url" {
  description = "Cedar PDP URL for authorization"
  value       = module.policy.cedar_pdp_url
}

output "opal_server_url" {
  description = "OPAL server URL for policy administration"
  value       = module.policy.opal_server_url
}

# -----------------------------------------------------------------------------
# CUI Data Tier Outputs (when enabled)
# -----------------------------------------------------------------------------
output "postgres_cui_host" {
  description = "CUI PostgreSQL read-write service endpoint"
  value       = var.cui_enabled ? module.data_cui[0].postgres_cui_host : null
}

output "minio_cui_endpoint" {
  description = "CUI MinIO S3 endpoint"
  value       = var.cui_enabled ? module.data_cui[0].minio_cui_endpoint : null
}

# -----------------------------------------------------------------------------
# Platform CRD Outputs
# -----------------------------------------------------------------------------
output "platform_namespace" {
  description = "Namespace for platform resources and CRDs"
  value       = module.provisioning.namespace
}
