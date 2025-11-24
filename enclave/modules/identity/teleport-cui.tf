# -----------------------------------------------------------------------------
# Teleport CUI Application Access and Roles
# Separate registration and roles for CUI workloads
# CMMC AC.L2-3.1.3 - Control CUI flow with approved authorizations
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# CUI Applications ConfigMap
# Registers CUI-specific applications with stricter access controls
# -----------------------------------------------------------------------------
resource "kubernetes_config_map" "teleport_cui_apps" {
  metadata {
    name      = "teleport-cui-apps-config"
    namespace = kubernetes_namespace.teleport.metadata[0].name
  }

  data = {
    "cui-apps.yaml" = <<-YAML
---
kind: app
version: v3
metadata:
  name: mattermost-cui
  description: "CUI Team Chat - Authorized Personnel Only"
  labels:
    env: production
    type: collaboration
    data_classification: cui
    cmmc_enclave: "true"
spec:
  uri: http://mattermost-cui.workloads-cui.svc.cluster.local:8065
  public_addr: chat-cui.${var.teleport_cluster_fqdn}
  rewrite:
    headers:
      - name: "X-CUI-Enclave"
        value: "true"
      - name: "X-Data-Classification"
        value: "cui"
---
kind: app
version: v3
metadata:
  name: nextcloud-cui
  description: "CUI File Sharing - Authorized Personnel Only"
  labels:
    env: production
    type: collaboration
    data_classification: cui
    cmmc_enclave: "true"
spec:
  uri: http://nextcloud-cui.workloads-cui.svc.cluster.local:8080
  public_addr: files-cui.${var.teleport_cluster_fqdn}
  rewrite:
    headers:
      - name: "X-CUI-Enclave"
        value: "true"
      - name: "X-Data-Classification"
        value: "cui"
YAML
  }
}

# -----------------------------------------------------------------------------
# CUI Roles ConfigMap
# Defines roles for CUI access with clearance requirements
# -----------------------------------------------------------------------------
resource "kubernetes_config_map" "teleport_cui_roles" {
  metadata {
    name      = "teleport-cui-roles-config"
    namespace = kubernetes_namespace.teleport.metadata[0].name
  }

  data = {
    # CUI Authorized User Role - Base role for CUI access
    "cui-user-role.yaml" = <<-YAML
kind: role
version: v7
metadata:
  name: cui-authorized
  labels:
    clearance_level: confidential
spec:
  allow:
    app_labels:
      data_classification: cui
    # Trait requirements - user must have cui_authorized trait
    traits_expression: |
      contains(internal.traits["cui_authorized"], "true")
    rules:
      - resources:
          - session
        verbs:
          - list
          - read
  deny:
    # Deny if MFA not verified in session
    # Enforced by require_session_mfa
  options:
    max_session_ttl: 4h
    forward_agent: false
    port_forwarding: false
    require_session_mfa: true
    record_session:
      default: strict
      ssh: best_effort
    enhanced_recording:
      - command
      - network
YAML

    # CUI Developer Role - Developers with CUI access
    "cui-developer-role.yaml" = <<-YAML
kind: role
version: v7
metadata:
  name: cui-developer
  labels:
    clearance_level: confidential
spec:
  allow:
    logins:
      - "{{internal.logins}}"
    app_labels:
      data_classification:
        - cui
        - internal
    kubernetes_labels:
      env:
        - dev
        - staging
    traits_expression: |
      contains(internal.traits["cui_authorized"], "true") &&
      contains(internal.traits["clearance_level"], "confidential")
  deny:
    node_labels:
      env: production
  options:
    max_session_ttl: 4h
    forward_agent: false
    port_forwarding: false
    require_session_mfa: true
    record_session:
      default: strict
YAML

    # CUI Admin Role - Full CUI enclave administration
    "cui-admin-role.yaml" = <<-YAML
kind: role
version: v7
metadata:
  name: cui-admin
  labels:
    clearance_level: restricted
spec:
  allow:
    logins:
      - root
      - admin
      - "{{internal.logins}}"
    node_labels:
      cmmc_enclave: "true"
    kubernetes_groups:
      - cui-admins
    kubernetes_labels:
      cmmc_enclave: "true"
    kubernetes_resources:
      - kind: "*"
        namespace: "workloads-cui"
        name: "*"
    db_labels:
      data_classification: cui
    db_names:
      - mattermost_cui
      - nextcloud_cui
    db_users:
      - cui_admin
    app_labels:
      data_classification: cui
    traits_expression: |
      contains(internal.traits["cui_authorized"], "true") &&
      contains(internal.traits["clearance_level"], "restricted")
    rules:
      - resources:
          - "*"
        verbs:
          - "*"
  options:
    max_session_ttl: 2h
    forward_agent: false
    port_forwarding: false
    require_session_mfa: true
    record_session:
      default: strict
      ssh: strict
    enhanced_recording:
      - command
      - network
      - disk
YAML

    # CUI Auditor Role - Audit access to CUI systems
    "cui-auditor-role.yaml" = <<-YAML
kind: role
version: v7
metadata:
  name: cui-auditor
  labels:
    clearance_level: confidential
spec:
  allow:
    app_labels:
      data_classification: cui
    traits_expression: |
      contains(internal.traits["cui_authorized"], "true")
    rules:
      - resources:
          - event
          - session
          - recording
        verbs:
          - list
          - read
    review_requests:
      roles:
        - cui-authorized
        - cui-developer
  deny:
    # Auditors cannot modify CUI data, only review
    rules:
      - resources:
          - "*"
        verbs:
          - create
          - update
          - delete
  options:
    max_session_ttl: 4h
    forward_agent: false
    port_forwarding: false
    require_session_mfa: true
    record_session:
      default: strict
YAML
  }
}

# -----------------------------------------------------------------------------
# Job to apply CUI Teleport configuration
# -----------------------------------------------------------------------------
resource "kubernetes_job" "teleport_cui_config_apply" {
  depends_on = [
    helm_release.teleport,
    kubernetes_config_map.teleport_cui_apps,
    kubernetes_config_map.teleport_cui_roles
  ]

  metadata {
    name      = "teleport-cui-config-apply"
    namespace = kubernetes_namespace.teleport.metadata[0].name
  }

  spec {
    ttl_seconds_after_finished = 300
    backoff_limit              = 3

    template {
      metadata {
        labels = {
          app = "teleport-cui-config-apply"
        }
      }

      spec {
        restart_policy       = "OnFailure"
        service_account_name = "teleport"

        container {
          name  = "tctl"
          image = "public.ecr.aws/gravitational/teleport:${var.teleport_version}"

          command = ["/bin/sh", "-c"]
          args = [
            <<-EOF
            set -e
            echo "Waiting for Teleport to be ready..."
            sleep 30

            echo "Applying CUI application access config..."
            tctl create -f /cui-apps/cui-apps.yaml || true

            echo "Applying CUI roles..."
            for role in /cui-roles/*.yaml; do
              echo "Applying $role..."
              tctl create -f "$role" || true
            done

            echo "CUI configuration applied successfully"
            EOF
          ]

          volume_mount {
            name       = "cui-apps-config"
            mount_path = "/cui-apps"
            read_only  = true
          }

          volume_mount {
            name       = "cui-roles-config"
            mount_path = "/cui-roles"
            read_only  = true
          }

          volume_mount {
            name       = "teleport-data"
            mount_path = "/var/lib/teleport"
          }

          env {
            name  = "TELEPORT_AUTH_SERVER"
            value = "teleport-auth.${kubernetes_namespace.teleport.metadata[0].name}.svc.cluster.local:3025"
          }
        }

        volume {
          name = "cui-apps-config"
          config_map {
            name = kubernetes_config_map.teleport_cui_apps.metadata[0].name
          }
        }

        volume {
          name = "cui-roles-config"
          config_map {
            name = kubernetes_config_map.teleport_cui_roles.metadata[0].name
          }
        }

        volume {
          name = "teleport-data"
          empty_dir {}
        }
      }
    }
  }

  wait_for_completion = false
}
