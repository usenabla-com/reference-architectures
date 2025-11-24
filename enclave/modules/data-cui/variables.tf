# -----------------------------------------------------------------------------
# Data CUI Module Variables
# Isolated CloudNative-PG + MinIO for CUI Workloads
# -----------------------------------------------------------------------------

variable "postgres_cui_config" {
  description = "CloudNative-PG configuration for CUI workloads"
  type = object({
    instances     = number
    storage_size  = string
    storage_class = string
  })
  default = {
    instances     = 3
    storage_size  = "100Gi"
    storage_class = "managed-csi-premium"
  }
}

variable "minio_cui_config" {
  description = "MinIO tenant configuration for CUI workloads"
  type = object({
    servers            = number
    volumes_per_server = number
    volume_size        = string
  })
  default = {
    servers            = 4
    volumes_per_server = 4
    volume_size        = "100Gi"
  }
}
