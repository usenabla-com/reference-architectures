# -----------------------------------------------------------------------------
# AKS Cluster Module
# FIPS-enabled, zero-trust ready Kubernetes cluster
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Virtual Network
# -----------------------------------------------------------------------------
resource "azurerm_virtual_network" "enclave" {
  name                = "${var.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "aks_nodes" {
  name                 = "aks-nodes"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.enclave.name
  address_prefixes     = [var.subnet_prefixes.aks_nodes]
}

resource "azurerm_subnet" "aks_pods" {
  name                 = "aks-pods"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.enclave.name
  address_prefixes     = [var.subnet_prefixes.aks_pods]

  delegation {
    name = "aks-delegation"
    service_delegation {
      name    = "Microsoft.ContainerService/managedClusters"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private_link" {
  name                                          = "private-link"
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.enclave.name
  address_prefixes                              = [var.subnet_prefixes.private_link]
  private_link_service_network_policies_enabled = true
}

# -----------------------------------------------------------------------------
# Network Security Groups
# -----------------------------------------------------------------------------
resource "azurerm_network_security_group" "aks" {
  name                = "${var.name_prefix}-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Default deny all inbound (zero trust)
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow internal VNet traffic
  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow Azure Load Balancer
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  # Allow HTTPS inbound for Teleport proxy
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks_nodes" {
  subnet_id                 = azurerm_subnet.aks_nodes.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# -----------------------------------------------------------------------------
# User Assigned Identity for AKS
# -----------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "aks" {
  name                = "${var.name_prefix}-aks-identity"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# Key Vault for secrets and encryption
# -----------------------------------------------------------------------------
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "enclave" {
  name                       = "${replace(var.name_prefix, "-", "")}kv"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium" # HSM-backed for CMMC
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  tags                       = var.tags

  # Enable RBAC for access control
  enable_rbac_authorization = true

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.aks_nodes.id]
  }
}

# Grant AKS identity access to Key Vault
resource "azurerm_role_assignment" "aks_keyvault_secrets" {
  scope                = azurerm_key_vault.enclave.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "aks_keyvault_crypto" {
  scope                = azurerm_key_vault.enclave.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# -----------------------------------------------------------------------------
# Disk Encryption Set (CMMC SC.L2-3.13.16 - Data at rest)
# -----------------------------------------------------------------------------
resource "azurerm_key_vault_key" "disk_encryption" {
  name         = "disk-encryption-key"
  key_vault_id = azurerm_key_vault.enclave.id
  key_type     = "RSA-HSM"
  key_size     = 4096
  key_opts     = ["decrypt", "encrypt", "wrapKey", "unwrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P365D"
    notify_before_expiry = "P30D"
  }
}

resource "azurerm_disk_encryption_set" "aks" {
  name                      = "${var.name_prefix}-disk-encryption"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  key_vault_key_id          = azurerm_key_vault_key.disk_encryption.id
  auto_key_rotation_enabled = true
  encryption_type           = "EncryptionAtRestWithPlatformAndCustomerKeys"
  tags                      = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "disk_encryption_keyvault" {
  scope                = azurerm_key_vault.enclave.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.aks.identity[0].principal_id
}

# -----------------------------------------------------------------------------
# Log Analytics Workspace (CMMC AU.L2-3.3.1 - Audit logging)
# -----------------------------------------------------------------------------
resource "azurerm_log_analytics_workspace" "enclave" {
  name                = "${var.name_prefix}-logs"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 90 # CMMC audit retention
  tags                = var.tags
}

# -----------------------------------------------------------------------------
# AKS Cluster
# -----------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "enclave" {
  name                = "${var.name_prefix}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.name_prefix
  kubernetes_version  = var.kubernetes_version
  tags                = var.tags

  # Use BYOCNI for Cilium
  network_profile {
    network_plugin = "none" # BYOCNI for Cilium
    network_policy = null
    outbound_type  = "loadBalancer"
  }

  # System node pool (non-FIPS for system workloads)
  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_pool.vm_size
    node_count                   = var.system_node_pool.node_count
    min_count                    = var.system_node_pool.min_count
    max_count                    = var.system_node_pool.max_count
    enable_auto_scaling          = true
    vnet_subnet_id               = azurerm_subnet.aks_nodes.id
    os_disk_type                 = "Managed"
    os_disk_size_gb              = 128
    only_critical_addons_enabled = true
    temporary_name_for_rotation  = "systemtmp"

    upgrade_settings {
      max_surge = "33%"
    }

    node_labels = {
      "usenabla.com/tier" = "system"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # Azure AD integration
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    tenant_id          = data.azurerm_client_config.current.tenant_id
  }

  # Enable Defender for security monitoring
  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.enclave.id
  }

  # OMS Agent for monitoring
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.enclave.id
  }

  # Key Vault secrets provider
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # Disk encryption
  disk_encryption_set_id = azurerm_disk_encryption_set.aks.id

  # Enable private cluster for zero trust
  private_cluster_enabled = false # Set to true for full zero-trust

  # Enable workload identity
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  # Image cleaner for security
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 24

  depends_on = [
    azurerm_role_assignment.disk_encryption_keyvault,
    azurerm_role_assignment.aks_keyvault_crypto_non_cui,
    azurerm_role_assignment.aks_keyvault_crypto_cui,
  ]
}

# -----------------------------------------------------------------------------
# FIPS-enabled Node Pools
# -----------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  for_each = var.workload_node_pools

  name                  = each.key
  kubernetes_cluster_id = azurerm_kubernetes_cluster.enclave.id
  vm_size               = each.value.vm_size
  node_count            = each.value.node_count
  min_count             = each.value.min_count
  max_count             = each.value.max_count
  enable_auto_scaling   = true
  vnet_subnet_id        = azurerm_subnet.aks_nodes.id
  os_disk_type          = "Managed"
  os_disk_size_gb       = 128
  fips_enabled          = each.value.fips_enabled # CMMC FIPS requirement
  node_labels           = each.value.labels
  node_taints           = each.value.taints
  tags                  = var.tags

  upgrade_settings {
    max_surge = "33%"
  }
}

# -----------------------------------------------------------------------------
# Diagnostic Settings
# -----------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "aks-diagnostics"
  target_resource_id         = azurerm_kubernetes_cluster.enclave.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.enclave.id

  enabled_log {
    category = "kube-apiserver"
  }
  enabled_log {
    category = "kube-controller-manager"
  }
  enabled_log {
    category = "kube-scheduler"
  }
  enabled_log {
    category = "kube-audit"
  }
  enabled_log {
    category = "kube-audit-admin"
  }
  enabled_log {
    category = "guard"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
