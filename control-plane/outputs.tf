# -----------------------------------------------------------------------------
# Control Plane - Outputs
# -----------------------------------------------------------------------------

output "cluster_name" {
  description = "Control plane AKS cluster name"
  value       = azurerm_kubernetes_cluster.control_plane.name
}

output "cluster_id" {
  description = "Control plane AKS cluster ID"
  value       = azurerm_kubernetes_cluster.control_plane.id
}

output "kube_config" {
  description = "Kubeconfig for control plane cluster"
  value = {
    host                   = azurerm_kubernetes_cluster.control_plane.kube_config[0].host
    client_certificate     = azurerm_kubernetes_cluster.control_plane.kube_config[0].client_certificate
    client_key             = azurerm_kubernetes_cluster.control_plane.kube_config[0].client_key
    cluster_ca_certificate = azurerm_kubernetes_cluster.control_plane.kube_config[0].cluster_ca_certificate
  }
  sensitive = true
}

output "resource_group_name" {
  description = "Control plane resource group name"
  value       = azurerm_resource_group.control_plane.name
}

output "crossplane_namespace" {
  description = "Namespace where Crossplane is installed"
  value       = "crossplane-system"
}

output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed (if enabled)"
  value       = var.enable_argocd ? "argocd" : null
}
