# -----------------------------------------------------------------------------
# Policy Module Outputs
# -----------------------------------------------------------------------------

output "opal_server_url" {
  description = "OPAL server URL for policy administration"
  value       = "http://opal-server.${kubernetes_namespace.policy.metadata[0].name}.svc.cluster.local:7002"
}

output "cedar_pdp_url" {
  description = "Cedar PDP URL for authorization decisions"
  value       = "http://cedar-pdp.${kubernetes_namespace.policy.metadata[0].name}.svc.cluster.local:8180"
}

output "opal_client_url" {
  description = "OPAL client URL for policy updates"
  value       = "http://cedar-pdp.${kubernetes_namespace.policy.metadata[0].name}.svc.cluster.local:7000"
}

output "policy_namespace" {
  description = "Policy system namespace"
  value       = kubernetes_namespace.policy.metadata[0].name
}
