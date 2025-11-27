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
  oidc_issuer_enabled = true
  kubernetes_version  = var.kubernetes_version

  # Note: Local accounts enabled to allow Terraform provisioning from HCP Terraform
  # AKS cluster is protected by Azure RBAC (azure_rbac_enabled = true)
  # Access is controlled via api_server_authorized_ip_ranges
  local_account_disabled = false

  # Security: Enable automatic upgrades with patch channel (azurerm 3.x naming)
  automatic_channel_upgrade = "patch"

  # Security: Restrict API server access to authorized IPs (only if ranges specified)
  dynamic "api_server_access_profile" {
    for_each = length(var.api_server_authorized_ip_ranges) > 0 ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

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
# Wait for Crossplane Providers to Install CRDs
# -----------------------------------------------------------------------------
resource "time_sleep" "wait_for_crd_installation" {
  create_duration = "2m"

  depends_on = [
    kubectl_manifest.provider_azure,
    kubectl_manifest.provider_terraform
  ]
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
    time_sleep.wait_for_crd_installation,
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
    time_sleep.wait_for_crd_installation,
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

# -----------------------------------------------------------------------------
# Teleport - Secure Access to Control Plane
# Uses the teleport-cluster Helm chart with the operator enabled
# -----------------------------------------------------------------------------
resource "helm_release" "teleport" {
  count = var.enable_teleport ? 1 : 0

  name             = "teleport"
  repository       = "https://charts.releases.teleport.dev"
  chart            = "teleport-cluster"
  version          = var.teleport_version
  namespace        = "teleport"
  create_namespace = true

  # Cluster configuration
  set {
    name  = "clusterName"
    value = var.teleport_cluster_name
  }

  # Enable the Kubernetes operator for managing roles via CRDs
  set {
    name  = "operator.enabled"
    value = "true"
  }

  # Azure-compatible storage (uses PVCs)
  set {
    name  = "chartMode"
    value = "standalone"
  }

  # Proxy service configuration
  set {
    name  = "proxy.service.type"
    value = "LoadBalancer"
  }

  # Enable Kubernetes access
  set {
    name  = "kubeClusterName"
    value = "${local.name_prefix}-aks"
  }

  # Enable ACME (Let's Encrypt) for automatic HTTPS certificates
  set {
    name  = "acme"
    value = "true"
  }

  set {
    name  = "acmeEmail"
    value = "james@usenabla.com"
  }

  # Authentication - will be configured with Entra ID SAML connector
  set {
    name  = "authentication.type"
    value = "saml"
  }

  set {
    name  = "authentication.connectorName"
    value = "entra-id"
  }

  # Enable local auth temporarily until SAML is fully configured (DNS + Entra ID)
  # Set to "false" once SAML SSO is working
  set {
    name  = "authentication.localAuth"
    value = "true"
  }

  set {
    name  = "operator.serviceAccount.annotations.azure.workload.identity/client-id"
    value = "e2a54522-83cb-49ff-a678-7231fb65ba77"
  }

  depends_on = [azurerm_kubernetes_cluster.control_plane]
}

# -----------------------------------------------------------------------------
# Teleport Entra ID SAML Connector
# Configures SSO with Microsoft Entra ID
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "teleport_saml_connector" {
  count = var.enable_teleport ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: resources.teleport.dev/v2
    kind: TeleportSAMLConnector
    metadata:
      name: entra-id
      namespace: teleport
    spec:
      display: "Microsoft Entra ID"
      acs: "https://${var.teleport_cluster_name}/v1/webapi/saml/acs/entra-id"
      entity_descriptor_url: "${var.entra_id_metadata_url}"
      attributes_to_roles:
        # Map Entra ID groups to Teleport roles
        - name: "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"
          value: "${var.entra_id_superadmin_group_id}"
          roles: ["superadmin"]
        - name: "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"
          value: "${var.entra_id_admin_group_id}"
          roles: ["admin"]
        - name: "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"
          value: "${var.entra_id_staff_group_id}"
          roles: ["staff"]
        - name: "http://schemas.microsoft.com/ws/2008/06/identity/claims/groups"
          value: "${var.entra_id_contractor_group_id}"
          roles: ["contractor"]
  YAML

  depends_on = [helm_release.teleport]
}

# -----------------------------------------------------------------------------
# Teleport Role: Superadmin (james@usenabla.com only)
# Full access to everything - no restrictions
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "teleport_role_superadmin" {
  count = var.enable_teleport ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: resources.teleport.dev/v1
    kind: TeleportRoleV7
    metadata:
      name: superadmin
      namespace: teleport
    spec:
      allow:
        # Full Kubernetes access
        kubernetes_groups: ["system:masters"]
        kubernetes_labels:
          '*': '*'
        kubernetes_resources:
          - kind: '*'
            namespace: '*'
            name: '*'
            verbs: ['*']
        # Full node/SSH access
        logins: ["root", "ubuntu", "admin"]
        node_labels:
          '*': '*'
        # Full database access
        db_labels:
          '*': '*'
        db_names: ['*']
        db_users: ['*']
        # Can review all access requests
        review_requests:
          roles: ['*']
        # Can impersonate any user (for debugging)
        impersonate:
          users: ['*']
          roles: ['*']
      options:
        max_session_ttl: 12h
        forward_agent: true
        port_forwarding: true
  YAML

  depends_on = [helm_release.teleport]
}

# -----------------------------------------------------------------------------
# Teleport Role: Admin
# High-level access, can approve requests, but cannot impersonate
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "teleport_role_admin" {
  count = var.enable_teleport ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: resources.teleport.dev/v1
    kind: TeleportRoleV7
    metadata:
      name: admin
      namespace: teleport
    spec:
      allow:
        # Kubernetes access - cluster-admin equivalent
        kubernetes_groups: ["system:masters"]
        kubernetes_labels:
          '*': '*'
        kubernetes_resources:
          - kind: '*'
            namespace: '*'
            name: '*'
            verbs: ['*']
        # SSH access to all nodes
        logins: ["ubuntu", "admin"]
        node_labels:
          '*': '*'
        # Database access
        db_labels:
          '*': '*'
        db_names: ['*']
        db_users: ['{{internal.db_users}}']
        # Can review access requests for staff and contractors
        review_requests:
          roles: ['staff', 'contractor']
        # Can request superadmin access (requires approval)
        request:
          roles: ['superadmin']
          suggested_reviewers: ['james@usenabla.com']
      deny:
        # Cannot impersonate users
        impersonate:
          users: ['*']
          roles: ['*']
      options:
        max_session_ttl: 8h
        forward_agent: true
        port_forwarding: true
  YAML

  depends_on = [helm_release.teleport]
}

# -----------------------------------------------------------------------------
# Teleport Role: Staff
# Standard employee access - production read, staging/dev write
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "teleport_role_staff" {
  count = var.enable_teleport ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: resources.teleport.dev/v1
    kind: TeleportRoleV7
    metadata:
      name: staff
      namespace: teleport
    spec:
      allow:
        # Kubernetes access - viewer in prod, admin in non-prod
        kubernetes_groups: ["nabla-staff"]
        kubernetes_labels:
          'env': ['dev', 'staging']
        kubernetes_resources:
          - kind: '*'
            namespace: '*'
            name: '*'
            verbs: ['*']
        # SSH access to non-production
        logins: ["ubuntu"]
        node_labels:
          'env': ['dev', 'staging']
        # Database access to non-production
        db_labels:
          'env': ['dev', 'staging']
        db_names: ['*']
        db_users: ['readonly', '{{email.local(external.email)}}']
        # Can request elevated access
        request:
          roles: ['admin']
          max_duration: 4h
          suggested_reviewers: ['james@usenabla.com']
        # Search production resources for access requests
        search_as_roles: ['admin']
      options:
        max_session_ttl: 8h
        forward_agent: false
        port_forwarding: true
        request_access: reason
        request_prompt: "Please provide a ticket ID or business justification"
  YAML

  depends_on = [helm_release.teleport]
}

# -----------------------------------------------------------------------------
# Teleport Role: Contractor
# Minimal access - specific namespaces only, requires access requests
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "teleport_role_contractor" {
  count = var.enable_teleport ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: resources.teleport.dev/v1
    kind: TeleportRoleV7
    metadata:
      name: contractor
      namespace: teleport
    spec:
      allow:
        # Kubernetes access - only dev environment, specific namespaces
        kubernetes_groups: ["nabla-contractor"]
        kubernetes_labels:
          'env': 'dev'
        kubernetes_resources:
          - kind: 'pod'
            namespace: 'dev-*'
            name: '*'
            verbs: ['get', 'list', 'watch', 'logs']
          - kind: 'deployment'
            namespace: 'dev-*'
            name: '*'
            verbs: ['get', 'list', 'watch']
          - kind: 'service'
            namespace: 'dev-*'
            name: '*'
            verbs: ['get', 'list', 'watch']
          - kind: 'configmap'
            namespace: 'dev-*'
            name: '*'
            verbs: ['get', 'list', 'watch']
        # No direct SSH access - must request
        # Can request staff access for specific tasks
        request:
          roles: ['staff']
          max_duration: 2h
          thresholds:
            - approve: 1
              deny: 1
        search_as_roles: ['staff']
      deny:
        # Explicitly deny production access
        kubernetes_labels:
          'env': 'production'
        node_labels:
          'env': 'production'
        db_labels:
          'env': 'production'
      options:
        max_session_ttl: 4h
        forward_agent: false
        port_forwarding: false
        request_access: always
        request_prompt: "Contractor access requires approval. Please provide ticket ID and scope of work."
  YAML

  depends_on = [helm_release.teleport]
}

# -----------------------------------------------------------------------------
# Teleport Role: Access Request Reviewer
# Allows admins to review and approve access requests
# -----------------------------------------------------------------------------
resource "kubectl_manifest" "teleport_role_reviewer" {
  count = var.enable_teleport ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: resources.teleport.dev/v1
    kind: TeleportRoleV7
    metadata:
      name: reviewer
      namespace: teleport
    spec:
      allow:
        review_requests:
          roles: ['admin', 'staff', 'contractor']
          preview_as_roles: ['admin', 'staff']
  YAML

  depends_on = [helm_release.teleport]
}

# -----------------------------------------------------------------------------
# Data sources for service IPs
# -----------------------------------------------------------------------------
data "kubernetes_service" "argocd_server" {
  count = var.enable_argocd ? 1 : 0
  metadata {
    name      = "argocd-server"
    namespace = "argocd"
  }
  depends_on = [helm_release.argocd]
}

data "kubernetes_service" "teleport_proxy" {
  count = var.enable_teleport ? 1 : 0
  metadata {
    name      = "teleport"
    namespace = "teleport"
  }
  depends_on = [helm_release.teleport]
}
