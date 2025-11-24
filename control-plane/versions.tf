# -----------------------------------------------------------------------------
# Control Plane - Terraform Configuration
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }

  # Use HCP Terraform for state
  cloud {
    organization = "usenabla"
    workspaces {
      name = "nabla-control-plane"
    }
  }
}

provider "azurerm" {
  features {}

  # Use Service Principal authentication for HCP Terraform
  client_id       = var.azure_client_id
  client_secret   = var.azure_client_secret
  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_tenant_id
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.control_plane.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.control_plane.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.control_plane.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.control_plane.kube_config[0].cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.control_plane.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.control_plane.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.control_plane.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.control_plane.kube_config[0].cluster_ca_certificate)
}

provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.control_plane.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.control_plane.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.control_plane.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.control_plane.kube_config[0].cluster_ca_certificate)
  load_config_file       = false
}
