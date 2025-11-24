# Crossplane Control Plane

Multi-tenant control plane for managing Nabla Enclave deployments across customer Azure subscriptions.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Control Plane (Your AKS)                                        │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Crossplane      │  │ provider-azure  │  │ provider-       │ │
│  │ Core            │  │                 │  │ terraform       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ EnclaveInstance CRD (usenabla.com/v1alpha1)             │   │
│  │ - Abstracts entire enclave deployment                    │   │
│  │ - One CR per customer                                    │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Creates & Manages
                              ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ Customer A       │  │ Customer B       │  │ Customer C       │
│ Azure Sub        │  │ Azure Sub        │  │ Azure Sub        │
│ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌──────────────┐ │
│ │ AKS Enclave  │ │  │ │ AKS Enclave  │ │  │ │ AKS Enclave  │ │
│ │ - Teleport   │ │  │ │ - Teleport   │ │  │ │ - Teleport   │ │
│ │ - Workloads  │ │  │ │ - Workloads  │ │  │ │ - Workloads  │ │
│ │ - Data       │ │  │ │ - Data       │ │  │ │ - Data       │ │
│ └──────────────┘ │  │ └──────────────┘ │  │ └──────────────┘ │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

## Directory Structure

```
crossplane/
├── README.md
├── providers/           # Crossplane provider configurations
│   ├── provider-azure.yaml
│   └── provider-terraform.yaml
├── compositions/        # How EnclaveInstance maps to resources
│   └── enclave-instance.yaml
├── claims/              # Example customer deployments
│   └── example-customer.yaml
└── functions/           # Composition functions (if needed)
```

## Prerequisites

1. Control plane AKS cluster with Crossplane installed
2. Azure Service Principal with permissions to create resources in customer subscriptions
3. Terraform Cloud/Enterprise workspace (for provider-terraform)

## Quick Start

```bash
# 1. Install Crossplane on control plane cluster
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm install crossplane crossplane-stable/crossplane -n crossplane-system --create-namespace

# 2. Install providers
kubectl apply -f providers/

# 3. Configure provider credentials (see providers/README.md)

# 4. Install XRDs and Compositions
kubectl apply -f compositions/

# 5. Create a customer enclave
kubectl apply -f claims/example-customer.yaml
```

## Usage

### Create a new customer enclave

```yaml
apiVersion: usenabla.com/v1alpha1
kind: EnclaveInstance
metadata:
  name: acme-corp
spec:
  customer: acme-corp
  domain: acme-corp.com
  clusterPrefix: enclave
  azure:
    subscriptionId: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    region: eastus2
  teleport:
    acmeEmail: admin@acme-corp.com
  sizing: medium
```

### Onboard a user to an enclave

```yaml
apiVersion: usenabla.com/v1alpha1
kind: UserOnboarding
metadata:
  name: john-doe-acme
spec:
  enclaveRef: acme-corp
  teleportUser: john.doe@acme-corp.com
  clearanceLevel: confidential
  cuiAuthorized: true
  applications:
    - name: mattermost
      instance: standard
    - name: mattermost
      instance: cui
```
