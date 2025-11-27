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

variable "api_server_authorized_ip_ranges" {
  description = "List of authorized IP ranges that can access the AKS API server"
  type        = list(string)
  default     = []
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

# -----------------------------------------------------------------------------
# Teleport Configuration
# -----------------------------------------------------------------------------
variable "enable_teleport" {
  description = "Enable Teleport for secure access to the control plane"
  type        = bool
  default     = true
}

variable "teleport_version" {
  description = "Teleport Helm chart version"
  type        = string
  default     = "18.0.0"
}

variable "teleport_cluster_name" {
  description = "Teleport cluster name (should be a FQDN, e.g., teleport.usenabla.com)"
  type        = string
}

# -----------------------------------------------------------------------------
# Teleport Entra ID SSO Configuration
# -----------------------------------------------------------------------------
variable "entra_id_metadata_url" {
  description = "Entra ID Federation Metadata URL for SAML SSO"
  type        = string
  default     = ""
}

variable "entra_id_superadmin_group_id" {
  description = "Entra ID group ID for Superadmin role (james@usenabla.com)"
  type        = string
  default     = ""
}

variable "entra_id_admin_group_id" {
  description = "Entra ID group ID for Admin role"
  type        = string
  default     = ""
}

variable "entra_id_staff_group_id" {
  description = "Entra ID group ID for Staff role"
  type        = string
  default     = ""
}

variable "entra_id_contractor_group_id" {
  description = "Entra ID group ID for Contractor role"
  type        = string
  default     = ""
}

