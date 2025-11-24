// =============================================================================
// Nabla Enclave - Nextcloud Application Policies
// File sharing and collaboration with CUI handling
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: User Nextcloud Access
// All authenticated users can access Nextcloud for file sharing
// MFA required due to confidential classification
// -----------------------------------------------------------------------------
@id("nextcloud-user-connect")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"connect",
  resource == Nabla::Application::"nextcloud"
) when {
  principal.mfaVerified
};

@id("nextcloud-user-read")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"read",
  resource == Nabla::Application::"nextcloud"
) when {
  principal.mfaVerified
};

@id("nextcloud-user-write")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"write",
  resource == Nabla::Application::"nextcloud"
) when {
  principal.mfaVerified
};

// -----------------------------------------------------------------------------
// POLICY: Nextcloud Database Access
// Nextcloud service account needs database access
// -----------------------------------------------------------------------------
@id("nextcloud-sa-db")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"connect",
  resource == Nabla::Database::"postgres-main"
) when {
  principal.workload == "nextcloud"
};

@id("nextcloud-sa-tables-read")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"read",
  resource is Nabla::DatabaseTable
) when {
  principal.workload == "nextcloud"
};

@id("nextcloud-sa-tables-write")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"write",
  resource is Nabla::DatabaseTable
) when {
  principal.workload == "nextcloud"
};

// -----------------------------------------------------------------------------
// POLICY: Nextcloud Storage Access
// Nextcloud needs access to MinIO for file storage
// -----------------------------------------------------------------------------
@id("nextcloud-sa-storage-connect")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"connect",
  resource == Nabla::StorageBucket::"minio-nextcloud"
) when {
  principal.workload == "nextcloud"
};

@id("nextcloud-sa-storage-read")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"read",
  resource == Nabla::StorageBucket::"minio-nextcloud"
) when {
  principal.workload == "nextcloud"
};

@id("nextcloud-sa-storage-write")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"write",
  resource == Nabla::StorageBucket::"minio-nextcloud"
) when {
  principal.workload == "nextcloud"
};

@id("nextcloud-sa-objects")
permit (
  principal is Nabla::ServiceAccount,
  action,
  resource is Nabla::StorageObject
) when {
  principal.workload == "nextcloud"
};

// -----------------------------------------------------------------------------
// POLICY: Nextcloud Admin Functions
// Only admins can perform administrative actions
// -----------------------------------------------------------------------------
@id("nextcloud-admin")
permit (
  principal in Nabla::Group::"Administrators",
  action == Nabla::Action::"admin",
  resource == Nabla::Application::"nextcloud"
);

// -----------------------------------------------------------------------------
// POLICY: Nextcloud Export Controls
// Export requires MFA and admin authorization for bulk exports
// CMMC MP.L2-3.8.2 - Limit CUI access
// -----------------------------------------------------------------------------
@id("nextcloud-export-require-mfa")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"export",
  resource == Nabla::Application::"nextcloud"
) when {
  !principal.mfaVerified
};
