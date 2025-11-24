# -----------------------------------------------------------------------------
# Data Module Variables
# CloudNative-PG + MinIO Configuration
# -----------------------------------------------------------------------------

variable "chainguard_registry" {
  description = "Chainguard container registry base URL"
  type        = string
}

variable "postgres_config" {
  description = "CloudNative-PG configuration"
  type = object({
    instances     = number
    storage_size  = string
    storage_class = string
  })
}

variable "minio_config" {
  description = "MinIO tenant configuration"
  type = object({
    servers            = number
    volumes_per_server = number
    volume_size        = string
  })
}

variable "openbao_address" {
  description = "OpenBao address for secrets management"
  type        = string
}

variable "cnpg_version" {
  description = "CloudNative-PG operator version"
  type        = string
  default     = "0.20.1"
}

variable "minio_operator_version" {
  description = "MinIO operator version"
  type        = string
  default     = "5.0.12"
}
