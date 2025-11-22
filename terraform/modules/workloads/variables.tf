# -----------------------------------------------------------------------------
# Workloads Module Variables
# Code-Server, Open-WebUI, Mattermost, Nextcloud
# -----------------------------------------------------------------------------

variable "chainguard_registry" {
  description = "Chainguard container registry base URL"
  type        = string
}

variable "postgres_host" {
  description = "PostgreSQL host for applications"
  type        = string
}

variable "minio_endpoint" {
  description = "MinIO S3 endpoint"
  type        = string
}

variable "openbao_address" {
  description = "OpenBao address for secrets"
  type        = string
}

variable "teleport_proxy_addr" {
  description = "Teleport proxy address for app access"
  type        = string
}

variable "code_server_version" {
  description = "Code-Server version"
  type        = string
  default     = "4.20.0"
}

variable "open_webui_version" {
  description = "Open-WebUI version"
  type        = string
  default     = "0.1.124"
}

variable "mattermost_version" {
  description = "Mattermost Helm chart version"
  type        = string
  default     = "7.1.3"
}

variable "nextcloud_version" {
  description = "Nextcloud Helm chart version"
  type        = string
  default     = "4.5.10"
}
