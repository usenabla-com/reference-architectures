# Nabla Enclave Policy Repository

CMMC-compliant Cedar policies for the Nabla Enclave zero-trust infrastructure, managed via OPAL (Open Policy Administration Layer).

## Overview

This repository contains:

- **Cedar Schema**: Entity type definitions for the enclave
- **Cedar Policies**: Authorization rules for RBAC, applications, and CMMC compliance
- **Entity Data**: Static entity definitions (groups, namespaces, applications)
- **OPAL Configuration**: Policy distribution and data sync configuration
- **Tests**: Policy validation and authorization tests

## Directory Structure

```
policies/
├── cedar/
│   ├── schema/
│   │   └── nabla.cedarschema    # Entity type definitions
│   ├── entities/
│   │   ├── groups.json          # User groups (Admin, Developer, Auditor)
│   │   ├── namespaces.json      # Kubernetes namespaces
│   │   ├── applications.json    # Workload applications
│   │   ├── databases.json       # Database resources
│   │   └── storage.json         # Storage buckets
│   └── policies/
│       ├── core/
│       │   ├── default.cedar         # Zero-trust default deny
│       │   ├── rbac.cedar            # Role-based access control
│       │   ├── service-accounts.cedar # Service account permissions
│       │   └── mfa-requirements.cedar # MFA enforcement
│       ├── applications/
│       │   ├── code-server.cedar     # VS Code access
│       │   ├── mattermost.cedar      # Team chat access
│       │   ├── nextcloud.cedar       # File sharing access
│       │   ├── observability.cedar   # Grafana/Gatus access
│       │   └── secrets.cedar         # OpenBao access
│       └── compliance/
│           ├── cmmc-access-control.cedar     # AC family controls
│           ├── cmmc-audit.cedar              # AU family controls
│           ├── cmmc-media-protection.cedar   # MP family controls
│           └── cmmc-identification-auth.cedar # IA family controls
├── opal/
│   ├── config/
│   │   ├── opal-server.yaml     # OPAL server configuration
│   │   └── opal-client.yaml     # OPAL client (PDP) configuration
│   └── data-sources/
│       ├── teleport-sync.yaml   # User/role sync from Teleport
│       └── kubernetes-sync.yaml # Resource sync from K8s
├── tests/
│   ├── test_policies.sh         # Policy validation script
│   └── authorization/
│       ├── admin-access.json    # Admin role tests
│       ├── developer-access.json # Developer role tests
│       └── cmmc-compliance.json # CMMC control tests
└── scripts/
    ├── validate.sh              # Pre-commit validation
    └── deploy.sh                # Deployment script
```

## Quick Start

### Prerequisites

- [Cedar CLI](https://github.com/cedar-policy/cedar) - `cargo install cedar-policy-cli`
- `jq` for JSON validation

### Validate Policies

```bash
./tests/test_policies.sh
```

### Deploy Policies

```bash
./scripts/deploy.sh
```

## Cedar Schema

The schema defines the following entity types:

### Principals (Who)
- `User` - Human users authenticated via Teleport
- `ServiceAccount` - Kubernetes service accounts for workloads
- `ExternalService` - External integrations
- `Group` - User groups (Administrators, Developers, Auditors)

### Resources (What)
- `Application` - Workload applications (code-server, mattermost, etc.)
- `Namespace` - Kubernetes namespaces
- `Database` / `DatabaseTable` - PostgreSQL resources
- `StorageBucket` / `StorageObject` - MinIO storage
- `Pod`, `Deployment`, `Secret`, `ConfigMap` - K8s resources
- `AuditLog`, `ComplianceReport` - Audit resources

### Actions (Operations)
- `read`, `write`, `delete` - Basic CRUD
- `execute` - Run commands/code
- `connect` - Establish connections
- `admin` - Administrative operations
- `export` - Data export (controlled for CUI)
- `audit` - Audit log access

## Policy Categories

### Core Policies

| Policy | Description |
|--------|-------------|
| `default.cedar` | Zero-trust default deny all |
| `rbac.cedar` | Maps Teleport roles to permissions |
| `service-accounts.cedar` | Workload-to-workload permissions |
| `mfa-requirements.cedar` | MFA enforcement rules |

### CMMC Compliance Policies

| Control Family | File | Key Controls |
|----------------|------|--------------|
| Access Control (AC) | `cmmc-access-control.cedar` | AC.L2-3.1.1 through 3.1.12 |
| Audit (AU) | `cmmc-audit.cedar` | AU.L2-3.3.1 through 3.3.9 |
| Media Protection (MP) | `cmmc-media-protection.cedar` | MP.L2-3.8.1 through 3.8.9 |
| Identification (IA) | `cmmc-identification-auth.cedar` | IA.L2-3.5.1 through 3.5.11 |

## Role Permissions

| Role | Applications | Databases | Storage | Admin Actions |
|------|--------------|-----------|---------|---------------|
| Administrators | All | All | All | Yes |
| Developers | Non-restricted | Non-restricted | Non-restricted | No |
| Auditors | Grafana, Gatus | Read-only | Audit logs only | No |
| ReadOnly | Public/Internal only | No | No | No |

## Data Flow

```
┌──────────────┐     Git Push      ┌──────────────┐
│   Policy     │ ─────────────────▶│    OPAL      │
│   Repo       │                   │   Server     │
└──────────────┘                   └──────┬───────┘
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
             ┌──────────────┐      ┌──────────────┐      ┌──────────────┐
             │ Cedar PDP    │      │ Cedar PDP    │      │ Cedar PDP    │
             │ (Replica 1)  │      │ (Replica 2)  │      │ (Replica 3)  │
             └──────────────┘      └──────────────┘      └──────────────┘
                    │                     │                     │
                    └─────────────────────┼─────────────────────┘
                                          │
                                          ▼
                                   ┌──────────────┐
                                   │  Workloads   │
                                   │  (AuthZ)     │
                                   └──────────────┘
```

## Integration with Teleport

User roles in Teleport map to Cedar groups:

| Teleport Role | Cedar Group |
|---------------|-------------|
| `admin` | `Nabla::Group::"Administrators"` |
| `developer` | `Nabla::Group::"Developers"` |
| `auditor` | `Nabla::Group::"Auditors"` |
| `access` | `Nabla::Group::"ReadOnly"` |

OPAL syncs user data from Teleport including:
- Email and department
- MFA verification status
- Active session IDs
- Role memberships

## Adding New Policies

1. Create a new `.cedar` file in the appropriate directory
2. Use the `@id("descriptive-id")` annotation for each policy
3. Reference entities from the schema
4. Run validation: `./tests/test_policies.sh`
5. Add authorization tests in `tests/authorization/`
6. Commit and push to trigger OPAL sync

### Policy Template

```cedar
// Description of what this policy does
// Reference: CMMC XX.L2-X.X.X (if applicable)
@id("unique-policy-id")
permit (
  principal in Nabla::Group::"GroupName",
  action == Nabla::Action::"actionName",
  resource is Nabla::ResourceType
) when {
  // conditions
};
```

## Contributing

1. Create a feature branch
2. Make policy changes
3. Run `./scripts/validate.sh`
4. Submit PR for review
5. Merge triggers automatic deployment via OPAL

## License

Internal use only - Nabla Enclave project.
