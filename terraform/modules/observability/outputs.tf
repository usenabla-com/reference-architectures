# -----------------------------------------------------------------------------
# Observability Module Outputs
# -----------------------------------------------------------------------------

output "prometheus_url" {
  description = "Prometheus server URL"
  value       = "http://prometheus-kube-prometheus-prometheus.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:9090"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = "http://prometheus-grafana.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:80"
}

output "alertmanager_url" {
  description = "AlertManager URL"
  value       = "http://prometheus-kube-prometheus-alertmanager.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:9093"
}

output "gatus_url" {
  description = "Gatus status page URL"
  value       = "http://gatus.${kubernetes_namespace.observability.metadata[0].name}.svc.cluster.local:8080"
}

output "namespace" {
  description = "Observability namespace"
  value       = kubernetes_namespace.observability.metadata[0].name
}
