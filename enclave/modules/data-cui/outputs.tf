# -----------------------------------------------------------------------------
# Data CUI Module Outputs
# Isolated PostgreSQL + MinIO endpoints for CUI workloads
# -----------------------------------------------------------------------------

output "postgres_cui_host" {
  description = "CUI PostgreSQL read-write service endpoint"
  value       = "enclave-postgres-cui-rw.${kubernetes_namespace.postgres_cui.metadata[0].name}.svc.cluster.local:5432"
}

output "postgres_cui_ro_host" {
  description = "CUI PostgreSQL read-only service endpoint"
  value       = "enclave-postgres-cui-ro.${kubernetes_namespace.postgres_cui.metadata[0].name}.svc.cluster.local:5432"
}

output "postgres_cui_namespace" {
  description = "CUI PostgreSQL namespace"
  value       = kubernetes_namespace.postgres_cui.metadata[0].name
}

output "minio_cui_endpoint" {
  description = "CUI MinIO S3 endpoint"
  value       = "https://minio-cui.${kubernetes_namespace.minio_cui.metadata[0].name}.svc.cluster.local:9000"
}

output "minio_cui_console_url" {
  description = "CUI MinIO console URL"
  value       = "https://minio-cui-console.${kubernetes_namespace.minio_cui.metadata[0].name}.svc.cluster.local:9001"
}

output "minio_cui_namespace" {
  description = "CUI MinIO namespace"
  value       = kubernetes_namespace.minio_cui.metadata[0].name
}

output "postgres_cui_credentials_secret" {
  description = "CUI PostgreSQL credentials secret name"
  value       = kubernetes_secret.postgres_cui_credentials.metadata[0].name
}

output "minio_cui_credentials_secret" {
  description = "CUI MinIO credentials secret name"
  value       = kubernetes_secret.minio_cui_credentials.metadata[0].name
}
