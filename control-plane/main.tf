# -----------------------------------------------------------------------------
# Control Plane - Main Configuration
# Deploys Crossplane and supporting infrastructure for provisioning customer enclaves
# -----------------------------------------------------------------------------

locals {
  name_prefix = "nabla-cp-${var.environment}"
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "nabla-control-plane"
    Component   = "crossplane"
  }
}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "control_plane" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# -----------------------------------------------------------------------------
# AKS Cluster for Control Plane
# Smaller cluster to run Crossplane and orchestrate customer deployments
# -----------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "control_plane" {
  name                = "${local.name_prefix}-aks"
  location            = azurerm_resource_group.control_plane.location
  resource_group_name = azurerm_resource_group.control_plane.name
  dns_prefix          = "${local.name_prefix}-aks"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "system"
    node_count          = var.node_count
    vm_size             = var.node_size
    os_disk_size_gb     = 50
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = var.node_count
    max_count           = var.node_count + 2
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    managed            = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  tags = local.common_tags
}

data "azurerm_client_config" "current" {}

# -----------------------------------------------------------------------------
# Virtual Network for Control Plane
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network" "control_plane" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.control_plane.location
  resource_group_name = azurerm_resource_group.control_plane.name
  address_space       = ["10.100.0.0/16"]
  tags                = local.common_tags
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.control_plane.name
  virtual_network_name = azurerm_virtual_network.control_plane.name
  address_prefixes     = ["10.100.0.0/22"]
}

# -----------------------------------------------------------------------------
# Crossplane Installation
# -----------------------------------------------------------------------------
resource "helm_release" "crossplane" {
  name             = "crossplane"
  repository       = "https://charts.crossplane.io/stable"
  chart            = "crossplane"
  version          = var.crossplane_version
  namespace        = "crossplane-system"
  create_namespace = true

  set {
    name  = "args"
    value = "{--enable-external-secret-stores}"
  }

  depends_on = [azurerm_kubernetes_cluster.control_plane]
}

# -----------------------------------------------------------------------------
# Crossplane Azure Provider
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "provider_azure" {
  yaml_body = <<-YAML
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: provider-azure
    spec:
      package: xpkg.upbound.io/upbound/provider-family-azure:${var.crossplane_azure_provider_version}
      controllerConfigRef:
        name: azure-config
  YAML

  depends_on = [helm_release.crossplane]
}

resource "kubectl_manifest" "provider_controller_config" {
  yaml_body = <<-YAML
    apiVersion: pkg.crossplane.io/v1alpha1
    kind: ControllerConfig
    metadata:
      name: azure-config
    spec:
      args:
        - --debug
  YAML

  depends_on = [helm_release.crossplane]
}

# -----------------------------------------------------------------------------
# Crossplane Terraform Provider (for enclave deployments)
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "provider_terraform" {
  yaml_body = <<-YAML
    apiVersion: pkg.crossplane.io/v1
    kind: Provider
    metadata:
      name: provider-terraform
    spec:
      package: xpkg.upbound.io/upbound/provider-terraform:${var.crossplane_terraform_provider_version}
  YAML

  depends_on = [helm_release.crossplane]
}

# -----------------------------------------------------------------------------
# Azure Credentials Secret for Crossplane
# This allows Crossplane to provision resources in customer subscriptions
# -----------------------------------------------------------------------------
resource "kubernetes_secret" "azure_credentials" {
  metadata {
    name      = "azure-credentials"
    namespace = "crossplane-system"
  }

  data = {
    credentials = jsonencode({
      clientId       = var.azure_client_id
      clientSecret   = var.azure_client_secret
      subscriptionId = var.azure_subscription_id
      tenantId       = var.azure_tenant_id
    })
  }

  depends_on = [helm_release.crossplane]
}

resource "kubectl_manifest" "provider_config_azure" {
  yaml_body = <<-YAML
    apiVersion: azure.upbound.io/v1beta1
    kind: ProviderConfig
    metadata:
      name: default
    spec:
      credentials:
        source: Secret
        secretRef:
          namespace: crossplane-system
          name: azure-credentials
          key: credentials
  YAML

  depends_on = [
    kubectl_manifest.provider_azure,
    kubernetes_secret.azure_credentials
  ]
}

# -----------------------------------------------------------------------------
# HCP Terraform Credentials for provider-terraform
# -----------------------------------------------------------------------------
resource "kubernetes_secret" "terraform_cloud_credentials" {
  metadata {
    name      = "terraform-cloud-credentials"
    namespace = "crossplane-system"
  }

  data = {
    credentials = jsonencode({
      token = var.hcp_terraform_token
    })
  }

  depends_on = [helm_release.crossplane]
}

resource "kubectl_manifest" "provider_config_terraform" {
  yaml_body = <<-YAML
    apiVersion: tf.upbound.io/v1beta1
    kind: ProviderConfig
    metadata:
      name: default
    spec:
      credentials:
        - filename: terraform.tfrc
          source: Secret
          secretRef:
            namespace: crossplane-system
            name: terraform-cloud-credentials
            key: credentials
      configuration: |
        credentials "app.terraform.io" {
          token = file("terraform.tfrc")
        }
  YAML

  depends_on = [
    kubectl_manifest.provider_terraform,
    kubernetes_secret.terraform_cloud_credentials
  ]
}

# -----------------------------------------------------------------------------
# ArgoCD for GitOps (optional, for managing XRDs/Compositions)
# -----------------------------------------------------------------------------
resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_version
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  depends_on = [azurerm_kubernetes_cluster.control_plane]
}
