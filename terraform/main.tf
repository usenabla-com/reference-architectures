# -----------------------------------------------------------------------------
# Nabla Enclave - Root Module
# CMMC-Compliant Zero Trust Infrastructure on AKS
# -----------------------------------------------------------------------------

locals {
  name_prefix = "${var.resource_prefix}-${var.environment}"
  common_tags = merge(var.tags, {
    Environment = var.environment
  })
}

# -----------------------------------------------------------------------------
# Azure Provider Configuration
# -----------------------------------------------------------------------------
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

provider "azuread" {}

# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------
resource "azurerm_resource_group" "enclave" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

# -----------------------------------------------------------------------------
# AKS Cluster Module
# -----------------------------------------------------------------------------
module "cluster" {
  source = "./modules/cluster"

  resource_group_name = azurerm_resource_group.enclave.name
  location            = azurerm_resource_group.enclave.location
  name_prefix         = local.name_prefix
  tags                = local.common_tags

  kubernetes_version  = var.kubernetes_version
  system_node_pool    = var.system_node_pool
  workload_node_pools = var.workload_node_pools

  vnet_address_space = var.vnet_address_space
  subnet_prefixes    = var.subnet_prefixes
}

# -----------------------------------------------------------------------------
# Kubernetes & Helm Providers (post-cluster)
# -----------------------------------------------------------------------------
provider "kubernetes" {
  host                   = module.cluster.kube_config.host
  client_certificate     = base64decode(module.cluster.kube_config.client_certificate)
  client_key             = base64decode(module.cluster.kube_config.client_key)
  cluster_ca_certificate = base64decode(module.cluster.kube_config.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.kube_config.host
    client_certificate     = base64decode(module.cluster.kube_config.client_certificate)
    client_key             = base64decode(module.cluster.kube_config.client_key)
    cluster_ca_certificate = base64decode(module.cluster.kube_config.cluster_ca_certificate)
  }
}

# -----------------------------------------------------------------------------
# Network Module (Cilium CNI)
# -----------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  depends_on = [module.cluster]

  chainguard_registry = var.chainguard_registry
  cluster_name        = module.cluster.cluster_name
}

# -----------------------------------------------------------------------------
# Identity Module (Teleport + JumpCloud SSO)
# -----------------------------------------------------------------------------
module "identity" {
  source = "./modules/identity"

  depends_on = [module.network]

  chainguard_registry = var.chainguard_registry
  teleport_config     = var.teleport_config
  jumpcloud_config    = var.jumpcloud_config
  cluster_name        = module.cluster.cluster_name
}

# -----------------------------------------------------------------------------
# Secrets Module (OpenBao)
# -----------------------------------------------------------------------------
module "secrets" {
  source = "./modules/secrets"

  depends_on = [module.network]

  chainguard_registry = var.chainguard_registry
  openbao_config      = var.openbao_config
  key_vault_id        = module.cluster.key_vault_id
}

# -----------------------------------------------------------------------------
# Policy Module (OPAL + Cedar)
# -----------------------------------------------------------------------------
module "policy" {
  source = "./modules/policy"

  depends_on = [module.network, module.identity]

  chainguard_registry = var.chainguard_registry
  opal_config         = var.opal_config
  teleport_auth_url   = module.identity.teleport_auth_address
}

# -----------------------------------------------------------------------------
# Data Tier Module (CloudNative-PG + MinIO)
# -----------------------------------------------------------------------------
module "data" {
  source = "./modules/data"

  depends_on = [module.secrets, module.policy]

  chainguard_registry = var.chainguard_registry
  postgres_config     = var.postgres_config
  minio_config        = var.minio_config
  openbao_address     = module.secrets.openbao_address
}

# -----------------------------------------------------------------------------
# Observability Module (Prometheus + Gatus)
# -----------------------------------------------------------------------------
module "observability" {
  source = "./modules/observability"

  depends_on = [module.network]

  chainguard_registry = var.chainguard_registry
  environment         = var.environment
}

# -----------------------------------------------------------------------------
# Security Scanning Module (Grype)
# -----------------------------------------------------------------------------
module "security_scanning" {
  source = "./modules/security-scanning"

  depends_on = [module.network]

  chainguard_registry = var.chainguard_registry
}

# -----------------------------------------------------------------------------
# Workloads Module (Code-Server, Open-WebUI, Mattermost, Nextcloud)
# -----------------------------------------------------------------------------
module "workloads" {
  source = "./modules/workloads"

  depends_on = [module.data, module.identity, module.policy]

  chainguard_registry = var.chainguard_registry
  postgres_host       = module.data.postgres_rw_service
  minio_endpoint      = module.data.minio_endpoint
  openbao_address     = module.secrets.openbao_address
  teleport_proxy_addr = module.identity.teleport_proxy_address
}

# -----------------------------------------------------------------------------
# Automation Module (GitHub Actions Runner)
# -----------------------------------------------------------------------------
module "automation" {
  source = "./modules/automation"

  depends_on = [module.data, module.secrets]

  chainguard_registry = var.chainguard_registry
  postgres_host       = module.data.postgres_rw_service
  openbao_address     = module.secrets.openbao_address
}
