{{/*
Generate OpenBao seal configuration based on seal type
Supports both openbao and openbaoCui configurations
*/}}
{{- define "nooklanes.openbao.sealConfig" -}}
{{- $config := . -}}
{{- if eq $config.seal.type "awskms" }}
seal "awskms" {
  region     = "{{ $config.seal.awskms.region }}"
  kms_key_id = "{{ $config.seal.awskms.kmsKeyId }}"
}
{{- else if eq $config.seal.type "azurekeyvault" }}
seal "azurekeyvault" {
  tenant_id  = "${AZURE_TENANT_ID}"
  vault_name = "{{ $config.seal.azurekeyvault.vaultName }}"
  key_name   = "{{ $config.seal.azurekeyvault.keyName }}"
}
{{- else if eq $config.seal.type "gcpckms" }}
seal "gcpckms" {
  project    = "{{ $config.seal.gcpckms.project }}"
  region     = "{{ $config.seal.gcpckms.location }}"
  key_ring   = "{{ $config.seal.gcpckms.keyRing }}"
  crypto_key = "{{ $config.seal.gcpckms.cryptoKey }}"
}
{{- else if eq $config.seal.type "transit" }}
seal "transit" {
  address         = "{{ $config.seal.transit.address }}"
  token           = "${TRANSIT_TOKEN}"
  disable_renewal = "false"
  key_name        = "{{ $config.seal.transit.keyName }}"
  mount_path      = "{{ $config.seal.transit.mountPath }}"
}
{{- end }}
{{- end -}}
