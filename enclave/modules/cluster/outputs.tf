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

output "non_cui_key_vault_id" {
  description = "Non-CUI Key Vault ID"
  value       = azurerm_key_vault.non_cui.id
}

output "non_cui_key_vault_uri" {
  description = "Non-CUI Key Vault URI"
  value       = azurerm_key_vault.non_cui.vault_uri
}

output "non_cui_key_vault_name" {
  description = "Non-CUI Key Vault Name"
  value       = azurerm_key_vault.non_cui.name
}

output "non_cui_unseal_key_name" {
  description = "Name of the OpenBao unseal key in the Non-CUI vault"
  value       = azurerm_key_vault_key.openbao_unseal_non_cui.name
}

output "cui_key_vault_id" {
  description = "CUI Key Vault ID"
  value       = azurerm_key_vault.cui.id
}

output "cui_key_vault_uri" {
  description = "CUI Key Vault URI"
  value       = azurerm_key_vault.cui.vault_uri
}

output "cui_key_vault_name" {
  description = "CUI Key Vault Name"
  value       = azurerm_key_vault.cui.name
}

output "cui_unseal_key_name" {
  description = "Name of the OpenBao unseal key in the CUI vault"
  value       = azurerm_key_vault_key.openbao_unseal_cui.name
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
