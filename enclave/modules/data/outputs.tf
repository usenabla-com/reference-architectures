# -----------------------------------------------------------------------------
# Data Module Outputs
# -----------------------------------------------------------------------------

output "postgres_rw_service" {
  description = "PostgreSQL read-write service endpoint"
  value       = "enclave-postgres-rw.${kubernetes_namespace.postgres.metadata[0].name}.svc.cluster.local:5432"
}

output "postgres_ro_service" {
  description = "PostgreSQL read-only service endpoint"
  value       = "enclave-postgres-ro.${kubernetes_namespace.postgres.metadata[0].name}.svc.cluster.local:5432"
}

output "postgres_namespace" {
  description = "PostgreSQL namespace"
  value       = kubernetes_namespace.postgres.metadata[0].name
}

output "minio_endpoint" {
  description = "MinIO S3 endpoint"
  value       = "https://minio.${kubernetes_namespace.minio.metadata[0].name}.svc.cluster.local:9000"
}

output "minio_console_url" {
  description = "MinIO console URL"
  value       = "https://minio-console.${kubernetes_namespace.minio.metadata[0].name}.svc.cluster.local:9001"
}

output "minio_namespace" {
  description = "MinIO namespace"
  value       = kubernetes_namespace.minio.metadata[0].name
}

output "postgres_credentials_secret" {
  description = "PostgreSQL credentials secret name"
  value       = kubernetes_secret.postgres_credentials.metadata[0].name
}

output "minio_credentials_secret" {
  description = "MinIO credentials secret name"
  value       = kubernetes_secret.minio_credentials.metadata[0].name
}
