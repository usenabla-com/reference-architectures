# Nooklanes Helm Chart

CMMC-compliant Kubernetes enclave with CUI/Non-CUI swimlane isolation.

## Overview

Nooklanes provides a secure, zero-trust Kubernetes enclave with dual data tiers for handling both Controlled Unclassified Information (CUI) and standard workloads.

**Key Features:**
- 🔐 **Zero-Trust Access** - Teleport for identity and application access
- 🔑 **Secrets Management** - OpenBao with multiple auto-unseal options
- 📋 **Policy Enforcement** - OPAL + Cedar for attribute-based access control
- 🏊 **Swimlane Isolation** - Separate CUI and Non-CUI data tiers
- 📊 **Observability** - Prometheus + Grafana + Gatus monitoring
- 🛡️ **Security Scanning** - Grype vulnerability scanning

## Architecture

```
Nooklanes Enclave
├── Shared Platform
│   ├── Teleport (identity & app access)
│   ├── OPAL + Cedar (policy enforcement)
│   └── Prometheus + Grafana (observability)
│
├── Non-CUI Swimlane
│   ├── workloads namespace
│   ├── OpenBao (secrets) - openbao namespace
│   ├── PostgreSQL cluster (postgres namespace)
│   └── MinIO tenant (minio namespace)
│
└── CUI Swimlane (CMMC Level 2 compliant)
    ├── workloads-cui namespace
    ├── OpenBao-CUI (secrets) - openbao-cui namespace - ISOLATED
    ├── PostgreSQL cluster (postgres-cui namespace) - encrypted
    └── MinIO tenant (minio-cui namespace) - encrypted

Note: Separate OpenBao instances enforce CMMC AC.L2-3.1.3 (Control CUI flow)
      - Different cryptographic boundaries
      - Separate KMS keys for auto-unseal
      - Network isolated
```

## Prerequisites

- Kubernetes 1.28+
- Helm 3.12+
- A domain name for Teleport (with DNS control)
- Storage class with encryption support (for CUI swimlane)

**Optional (for auto-unseal):**
- AWS KMS key, Azure Key Vault, or GCP Cloud KMS

## Quick Start

### 1. Add Dependencies

```bash
helm repo add teleport https://charts.releases.teleport.dev
helm repo add cloudnative-pg https://cloudnative-pg.github.io/charts
helm repo add minio-operator https://operator.min.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 2. Configure Values

Copy `values.yaml` and customize:

```yaml
global:
  domain: "enclave.yourdomain.com"

identity:
  teleport:
    acme:
      email: "admin@yourdomain.com"

secrets:
  openbao:
    seal:
      type: "awskms"  # or "azurekeyvault", "gcpckms", "shamir"
      awskms:
        region: "us-east-1"
        kmsKeyId: "arn:aws:kms:..."

policy:
  opal:
    policyRepo:
      url: "git@github.com:yourorg/policies.git"
      sshKey: "YOUR_SSH_KEY"

swimlanes:
  cuiEnabled: true  # Enable CUI swimlane
```

### 3. Install

```bash
helm install nooklanes ./nooklanes-helm \\
  --namespace nooklanes-system \\
  --create-namespace \\
  --values custom-values.yaml
```

### 4. Configure DNS

Get the Teleport LoadBalancer IP:

```bash
kubectl get svc -n teleport teleport -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Create DNS A records:
- `enclave.yourdomain.com` → LoadBalancer IP
- `*.enclave.yourdomain.com` → LoadBalancer IP

### 5. Initialize OpenBao

**For Shamir (manual unseal):**

```bash
kubectl exec -n openbao openbao-0 -- bao operator init
# Save unseal keys and root token!

# Unseal all replicas
for i in 0 1 2; do
  kubectl exec -n openbao openbao-$i -- bao operator unseal <key1>
  kubectl exec -n openbao openbao-$i -- bao operator unseal <key2>
  kubectl exec -n openbao openbao-$i -- bao operator unseal <key3>
done
```

**For auto-unseal (AWS KMS, Azure Key Vault, GCP KMS):**

OpenBao will automatically unseal on startup. Just initialize once:

```bash
kubectl exec -n openbao openbao-0 -- bao operator init
```

### 6. Access Teleport

```bash
# Get initial admin invite link
kubectl exec -n teleport deployment/teleport -- tctl users add admin --roles=admin

# Visit https://enclave.yourdomain.com and complete setup
```

## CUI/Non-CUI Swimlanes

### Deploying to Non-CUI Swimlane

Applications in the `workloads` namespace access standard data tier:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: workloads
```

### Deploying to CUI Swimlane

Applications in the `workloads-cui` namespace access encrypted CUI data tier:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cui-app
  namespace: workloads-cui
```

**Cedar policies automatically enforce:**
- CUI workloads can ONLY access CUI databases/storage
- Non-CUI workloads are BLOCKED from CUI data
- Users must have `cuiAuthorized` attribute and MFA

## Configuration

### Auto-Unseal Options

**AWS KMS:**
```yaml
secrets:
  openbao:
    seal:
      type: "awskms"
      awskms:
        region: "us-east-1"
        kmsKeyId: "arn:aws:kms:us-east-1:123456789:key/..."
```

**Azure Key Vault:**
```yaml
secrets:
  openbao:
    seal:
      type: "azurekeyvault"
      azurekeyvault:
        vaultName: "my-keyvault"
        keyName: "openbao-unseal"
        clientId: "..."  # For workload identity
```

**GCP Cloud KMS:**
```yaml
secrets:
  openbao:
    seal:
      type: "gcpckms"
      gcpckms:
        project: "my-project"
        keyRing: "openbao"
        cryptoKey: "openbao-unseal"
```

### Disable CUI Swimlane

```yaml
swimlanes:
  cuiEnabled: false
```

This removes the CUI data tier and only provisions the standard swimlane.

## Crossplane Integration

This chart is designed to work with Crossplane compositions:

- `EnclaveInstance` - Provisions the entire enclave
- `EnclaveApplication` - Deploys apps with `cuiWorkload` flag

See the `crossplane/` directory for XRD definitions.

## Monitoring

Access Grafana:
```bash
kubectl port-forward -n observability svc/kube-prometheus-stack-grafana 3000:80
```

Default credentials: `admin` / (get from secret)

## Troubleshooting

### Pods stuck in Pending

Check storage class:
```bash
kubectl get storageclass
kubectl get pvc -A
```

### OpenBao not unsealing

Check seal configuration:
```bash
kubectl logs -n openbao openbao-0
```

For cloud KMS auto-unseal, verify IAM permissions.

### Network policies blocking traffic

Temporarily disable for debugging:
```bash
kubectl delete networkpolicy --all -A
```

## Security

- All network traffic is denied by default (zero-trust)
- CUI and Non-CUI swimlanes are network-isolated
- Cedar policies enforce application-level access control
- All images use Chainguard minimal containers
- Pod security standards enforced (restricted)

## License

Internal use - Nabla Nooklanes

## Support

- Issues: https://github.com/usenabla-com/nabla-enclave/issues
- Docs: https://docs.usenabla.com
