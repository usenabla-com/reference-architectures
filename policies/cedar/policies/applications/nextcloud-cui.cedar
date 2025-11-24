// =============================================================================
// Nabla Enclave - Nextcloud CUI Application Policies
// CUI file sharing with strict access controls
// CMMC AC.L2-3.1.3, MP.L2-3.8.2 - CUI flow and media protection
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: CUI Nextcloud Access - Requires CUI Authorization + MFA
// Only users with cui_authorized trait and MFA can access
// -----------------------------------------------------------------------------
@id("nextcloud-cui-user-connect")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"connect",
  resource == Nabla::Application::"nextcloud-cui"
) when {
  principal.mfaVerified &&
  principal.cuiAuthorized &&
  (principal.clearanceLevel == "confidential" ||
   principal.clearanceLevel == "restricted")
};

@id("nextcloud-cui-user-read")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"read",
  resource == Nabla::Application::"nextcloud-cui"
) when {
  principal.mfaVerified &&
  principal.cuiAuthorized &&
  (principal.clearanceLevel == "confidential" ||
   principal.clearanceLevel == "restricted")
};

@id("nextcloud-cui-user-write")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"write",
  resource == Nabla::Application::"nextcloud-cui"
) when {
  principal.mfaVerified &&
  principal.cuiAuthorized &&
  (principal.clearanceLevel == "confidential" ||
   principal.clearanceLevel == "restricted")
};

// -----------------------------------------------------------------------------
// POLICY: Deny CUI Access Without Authorization
// Explicit deny for users without CUI authorization
// -----------------------------------------------------------------------------
@id("nextcloud-cui-deny-unauthorized")
forbid (
  principal is Nabla::User,
  action,
  resource == Nabla::Application::"nextcloud-cui"
) when {
  !principal.cuiAuthorized
};

@id("nextcloud-cui-deny-no-mfa")
forbid (
  principal is Nabla::User,
  action,
  resource == Nabla::Application::"nextcloud-cui"
) when {
  !principal.mfaVerified
};

@id("nextcloud-cui-deny-low-clearance")
forbid (
  principal is Nabla::User,
  action,
  resource == Nabla::Application::"nextcloud-cui"
) when {
  principal.clearanceLevel == "public" ||
  principal.clearanceLevel == "internal"
};

// -----------------------------------------------------------------------------
// POLICY: Nextcloud CUI Database Access
// -----------------------------------------------------------------------------
@id("nextcloud-cui-sa-db")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"connect",
  resource == Nabla::Database::"postgres-cui"
) when {
  principal.workload == "nextcloud-cui" &&
  principal.namespace == "workloads-cui"
};

@id("nextcloud-cui-sa-tables-read")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"read",
  resource is Nabla::DatabaseTable
) when {
  principal.workload == "nextcloud-cui" &&
  principal.namespace == "workloads-cui"
};

@id("nextcloud-cui-sa-tables-write")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"write",
  resource is Nabla::DatabaseTable
) when {
  principal.workload == "nextcloud-cui" &&
  principal.namespace == "workloads-cui"
};

// -----------------------------------------------------------------------------
// POLICY: Nextcloud CUI Storage Access (MinIO)
// Separate CUI storage bucket
// -----------------------------------------------------------------------------
@id("nextcloud-cui-sa-storage-connect")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"connect",
  resource == Nabla::StorageBucket::"minio-nextcloud-cui"
) when {
  principal.workload == "nextcloud-cui" &&
  principal.namespace == "workloads-cui"
};

@id("nextcloud-cui-sa-storage-read")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"read",
  resource == Nabla::StorageBucket::"minio-nextcloud-cui"
) when {
  principal.workload == "nextcloud-cui" &&
  principal.namespace == "workloads-cui"
};

@id("nextcloud-cui-sa-storage-write")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"write",
  resource == Nabla::StorageBucket::"minio-nextcloud-cui"
) when {
  principal.workload == "nextcloud-cui" &&
  principal.namespace == "workloads-cui"
};

@id("nextcloud-cui-sa-objects")
permit (
  principal is Nabla::ServiceAccount,
  action,
  resource is Nabla::StorageObject
) when {
  principal.workload == "nextcloud-cui" &&
  principal.namespace == "workloads-cui"
};

// -----------------------------------------------------------------------------
// POLICY: CUI Admin Functions - Restricted clearance only
// -----------------------------------------------------------------------------
@id("nextcloud-cui-admin")
permit (
  principal in Nabla::Group::"CUIAdministrators",
  action == Nabla::Action::"admin",
  resource == Nabla::Application::"nextcloud-cui"
) when {
  principal.mfaVerified &&
  principal.clearanceLevel == "restricted"
};

// -----------------------------------------------------------------------------
// POLICY: Block All Export from CUI Nextcloud
// CMMC MP.L2-3.8.2 - Limit CUI access and prevent data exfiltration
// -----------------------------------------------------------------------------
@id("nextcloud-cui-deny-export")
forbid (
  principal,
  action == Nabla::Action::"export",
  resource == Nabla::Application::"nextcloud-cui"
);

// -----------------------------------------------------------------------------
// POLICY: CUI Auditor Read-Only Access
// Auditors can view CUI files but not modify
// -----------------------------------------------------------------------------
@id("nextcloud-cui-auditor-read")
permit (
  principal in Nabla::Group::"CUIAuditors",
  action == Nabla::Action::"read",
  resource == Nabla::Application::"nextcloud-cui"
) when {
  principal.mfaVerified &&
  principal.cuiAuthorized
};

@id("nextcloud-cui-auditor-connect")
permit (
  principal in Nabla::Group::"CUIAuditors",
  action == Nabla::Action::"connect",
  resource == Nabla::Application::"nextcloud-cui"
) when {
  principal.mfaVerified &&
  principal.cuiAuthorized
};

// Auditors cannot write to CUI Nextcloud
@id("nextcloud-cui-auditor-deny-write")
forbid (
  principal in Nabla::Group::"CUIAuditors",
  action == Nabla::Action::"write",
  resource == Nabla::Application::"nextcloud-cui"
);
