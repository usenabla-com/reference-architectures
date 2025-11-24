// =============================================================================
// Nabla Enclave - Service Account Policies
// Controls workload-to-workload and service-to-resource access
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: Service Account Namespace Isolation
// Service accounts can only access resources in their own namespace
// -----------------------------------------------------------------------------
@id("sa-namespace-isolation")
permit (
  principal is Nabla::ServiceAccount,
  action,
  resource is Nabla::Pod
) when {
  principal.namespace == resource.namespace
};

@id("sa-deployment-access")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"read",
  resource is Nabla::Deployment
) when {
  principal.namespace == resource.namespace
};

@id("sa-configmap-read")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"read",
  resource is Nabla::ConfigMap
) when {
  principal.namespace == resource.namespace
};

// -----------------------------------------------------------------------------
// POLICY: Workload Service Account Database Access
// Workload service accounts can connect to their designated databases
// -----------------------------------------------------------------------------
@id("workload-sa-db-connect")
permit (
  principal in Nabla::Group::"WorkloadServiceAccounts",
  action == Nabla::Action::"connect",
  resource is Nabla::Database
);

@id("workload-sa-db-read")
permit (
  principal in Nabla::Group::"WorkloadServiceAccounts",
  action == Nabla::Action::"read",
  resource is Nabla::DatabaseTable
);

@id("workload-sa-db-write")
permit (
  principal in Nabla::Group::"WorkloadServiceAccounts",
  action == Nabla::Action::"write",
  resource is Nabla::DatabaseTable
);

// -----------------------------------------------------------------------------
// POLICY: Data Service Account Full Database Access
// Data tier service accounts have full database access for operations
// -----------------------------------------------------------------------------
@id("data-sa-db-full")
permit (
  principal in Nabla::Group::"DataServiceAccounts",
  action,
  resource is Nabla::Database
);

@id("data-sa-table-full")
permit (
  principal in Nabla::Group::"DataServiceAccounts",
  action,
  resource is Nabla::DatabaseTable
);

// -----------------------------------------------------------------------------
// POLICY: Service Account Storage Access
// Service accounts can access storage within their designated buckets
// -----------------------------------------------------------------------------
@id("workload-sa-storage-read")
permit (
  principal in Nabla::Group::"WorkloadServiceAccounts",
  action == Nabla::Action::"read",
  resource is Nabla::StorageBucket
) when {
  resource.dataClassification != "restricted"
};

@id("workload-sa-storage-write")
permit (
  principal in Nabla::Group::"WorkloadServiceAccounts",
  action == Nabla::Action::"write",
  resource is Nabla::StorageBucket
) when {
  resource.dataClassification != "restricted"
};

@id("workload-sa-object-access")
permit (
  principal in Nabla::Group::"WorkloadServiceAccounts",
  action,
  resource is Nabla::StorageObject
);

// -----------------------------------------------------------------------------
// POLICY: Service Account Secret Access - Restricted
// Service accounts can only read secrets in their namespace
// Cannot write/delete secrets (managed by OpenBao)
// -----------------------------------------------------------------------------
@id("sa-secret-read")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"read",
  resource is Nabla::Secret
) when {
  principal.namespace == resource.namespace
};

// -----------------------------------------------------------------------------
// POLICY: Deny Service Account Cross-Namespace Secret Access
// Explicitly deny any cross-namespace secret access
// -----------------------------------------------------------------------------
@id("sa-secret-cross-ns-deny")
forbid (
  principal is Nabla::ServiceAccount,
  action,
  resource is Nabla::Secret
) when {
  principal.namespace != resource.namespace
};
