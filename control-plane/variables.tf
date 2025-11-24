# -----------------------------------------------------------------------------
# Control Plane - Variables
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "location" {
  description = "Azure region for control plane resources"
  type        = string
  default     = "eastus2"
}

# -----------------------------------------------------------------------------
# AKS Configuration
# -----------------------------------------------------------------------------
variable "kubernetes_version" {
  description = "Kubernetes version for control plane AKS"
  type        = string
  default     = "1.30"
}

variable "node_count" {
  description = "Number of nodes in control plane cluster"
  type        = number
  default     = 3
}

variable "node_size" {
  description = "VM size for control plane nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

# -----------------------------------------------------------------------------
# Crossplane Configuration
# -----------------------------------------------------------------------------
variable "crossplane_version" {
  description = "Crossplane Helm chart version"
  type        = string
  default     = "1.15.0"
}

variable "crossplane_azure_provider_version" {
  description = "Crossplane Azure provider version"
  type        = string
  default     = "v1.0.0"
}

variable "crossplane_terraform_provider_version" {
  description = "Crossplane Terraform provider version"
  type        = string
  default     = "v0.14.0"
}

# -----------------------------------------------------------------------------
# Azure Credentials (for Crossplane to provision customer resources)
# -----------------------------------------------------------------------------
variable "azure_client_id" {
  description = "Azure Service Principal client ID for Crossplane"
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure Service Principal client secret for Crossplane"
  type        = string
  sensitive   = true
}

variable "azure_subscription_id" {
  description = "Azure subscription ID for Crossplane"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure tenant ID for Crossplane"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# HCP Terraform Configuration
# -----------------------------------------------------------------------------
variable "hcp_terraform_token" {
  description = "HCP Terraform API token for provider-terraform"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Optional Components
# -----------------------------------------------------------------------------
variable "enable_argocd" {
  description = "Enable ArgoCD for GitOps management of XRDs/Compositions"
  type        = bool
  default     = true
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.0"
}
