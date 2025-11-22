output "cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.enclave.name
}

output "cluster_id" {
  description = "AKS cluster ID"
  value       = azurerm_kubernetes_cluster.enclave.id
}

output "cluster_fqdn" {
  description = "AKS cluster FQDN"
  value       = azurerm_kubernetes_cluster.enclave.fqdn
}

output "cluster_identity" {
  description = "AKS cluster managed identity"
  value = {
    principal_id = azurerm_user_assigned_identity.aks.principal_id
    client_id    = azurerm_user_assigned_identity.aks.client_id
    tenant_id    = azurerm_user_assigned_identity.aks.tenant_id
  }
}

output "kube_config" {
  description = "Kubernetes configuration"
  value = {
    host                   = azurerm_kubernetes_cluster.enclave.kube_config[0].host
    client_certificate     = azurerm_kubernetes_cluster.enclave.kube_config[0].client_certificate
    client_key             = azurerm_kubernetes_cluster.enclave.kube_config[0].client_key
    cluster_ca_certificate = azurerm_kubernetes_cluster.enclave.kube_config[0].cluster_ca_certificate
  }
  sensitive = true
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity"
  value       = azurerm_kubernetes_cluster.enclave.oidc_issuer_url
}

output "key_vault_id" {
  description = "Key Vault ID"
  value       = azurerm_key_vault.enclave.id
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.enclave.vault_uri
}

output "vnet_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.enclave.id
}

output "aks_subnet_id" {
  description = "AKS nodes subnet ID"
  value       = azurerm_subnet.aks_nodes.id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID"
  value       = azurerm_log_analytics_workspace.enclave.id
}
