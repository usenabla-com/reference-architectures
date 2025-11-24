// =============================================================================
// Nabla Enclave - CUI Enclave Access Control Policies
// CMMC Level 2 - CUI-Specific Controls
// AC.L2-3.1.3 - Control CUI flow with approved authorizations
// MP.L2-3.8.2 - Limit access to CUI on system media
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: CUI Enclave Base Access
// Only CUI-authorized users can access CUI enclave applications
// -----------------------------------------------------------------------------
@id("cui-enclave-base-access")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Application
) when {
  resource.cuiEnclave &&
  !principal.cuiAuthorized
};

// -----------------------------------------------------------------------------
// POLICY: CUI Enclave MFA Requirement
// All CUI enclave access requires verified MFA
// -----------------------------------------------------------------------------
@id("cui-enclave-require-mfa")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Application
) when {
  resource.cuiEnclave &&
  !principal.mfaVerified
};

// -----------------------------------------------------------------------------
// POLICY: CUI Enclave Clearance Requirement
// CUI enclave requires at least confidential clearance
// -----------------------------------------------------------------------------
@id("cui-enclave-clearance-confidential")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Application
) when {
  resource.cuiEnclave &&
  (principal.clearanceLevel == "public" ||
   principal.clearanceLevel == "internal")
};

// -----------------------------------------------------------------------------
// POLICY: CUI Data Export Prohibition
// No export actions allowed on CUI enclave resources
// CMMC MP.L2-3.8.2 - Limit CUI access
// -----------------------------------------------------------------------------
@id("cui-enclave-deny-export")
forbid (
  principal,
  action == Nabla::Action::"export",
  resource is Nabla::Application
) when {
  resource.cuiEnclave
};

// -----------------------------------------------------------------------------
// POLICY: CUI Database Access Control
// CUI databases require CUI authorization
// -----------------------------------------------------------------------------
@id("cui-database-require-authorization")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Database
) when {
  resource.dataClassification == "cui" &&
  !principal.cuiAuthorized
};

@id("cui-database-require-mfa")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Database
) when {
  resource.dataClassification == "cui" &&
  !principal.mfaVerified
};

// -----------------------------------------------------------------------------
// POLICY: CUI Storage Access Control
// CUI storage buckets require CUI authorization
// -----------------------------------------------------------------------------
@id("cui-storage-require-authorization")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::StorageBucket
) when {
  resource.dataClassification == "cui" &&
  !principal.cuiAuthorized
};

@id("cui-storage-require-mfa")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::StorageBucket
) when {
  resource.dataClassification == "cui" &&
  !principal.mfaVerified
};

// -----------------------------------------------------------------------------
// POLICY: CUI Storage Object Export Control
// Prevent export of CUI storage objects
// -----------------------------------------------------------------------------
@id("cui-storage-object-deny-export")
forbid (
  principal,
  action == Nabla::Action::"export",
  resource is Nabla::StorageObject
) when {
  resource in Nabla::StorageBucket::"minio-nextcloud-cui"
};

// -----------------------------------------------------------------------------
// POLICY: CUI Namespace Protection
// Only CUI-authorized users can access CUI namespace resources
// -----------------------------------------------------------------------------
@id("cui-namespace-require-authorization")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Namespace
) when {
  resource.name == "workloads-cui" &&
  !principal.cuiAuthorized
};

@id("cui-namespace-require-clearance")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Namespace
) when {
  resource.name == "workloads-cui" &&
  (principal.clearanceLevel == "public" ||
   principal.clearanceLevel == "internal")
};

// -----------------------------------------------------------------------------
// POLICY: CUI Admin Actions
// Only CUI Administrators can perform admin actions on CUI resources
// -----------------------------------------------------------------------------
@id("cui-admin-actions-restricted")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"admin",
  resource is Nabla::Application
) when {
  resource.cuiEnclave
} unless {
  principal in Nabla::Group::"CUIAdministrators"
};

// -----------------------------------------------------------------------------
// POLICY: CUI Write Access - Restricted to Authorized Personnel
// Write access to CUI applications requires CUI authorization
// -----------------------------------------------------------------------------
@id("cui-write-require-authorization")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"write",
  resource is Nabla::Application
) when {
  resource.cuiEnclave &&
  !principal.cuiAuthorized
};

// -----------------------------------------------------------------------------
// POLICY: CUI Delete Prohibition
// Delete actions on CUI resources require admin privileges
// Preserves audit trail and data integrity
// -----------------------------------------------------------------------------
@id("cui-delete-admin-only")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"delete",
  resource is Nabla::Application
) when {
  resource.cuiEnclave
} unless {
  principal in Nabla::Group::"CUIAdministrators"
};

// -----------------------------------------------------------------------------
// POLICY: Service Account CUI Access
// Service accounts in CUI namespace can only access CUI resources
// -----------------------------------------------------------------------------
@id("cui-sa-namespace-isolation")
forbid (
  principal is Nabla::ServiceAccount,
  action,
  resource is Nabla::Application
) when {
  principal.namespace == "workloads-cui" &&
  !resource.cuiEnclave
};

// Non-CUI service accounts cannot access CUI resources
@id("non-cui-sa-deny-cui-access")
forbid (
  principal is Nabla::ServiceAccount,
  action,
  resource is Nabla::Application
) when {
  principal.namespace != "workloads-cui" &&
  resource.cuiEnclave
};

// -----------------------------------------------------------------------------
// POLICY: External Service CUI Denial
// External services cannot access CUI resources
// -----------------------------------------------------------------------------
@id("external-service-deny-cui")
forbid (
  principal is Nabla::ExternalService,
  action,
  resource is Nabla::Application
) when {
  resource.cuiEnclave
};

@id("external-service-deny-cui-db")
forbid (
  principal is Nabla::ExternalService,
  action,
  resource is Nabla::Database
) when {
  resource.dataClassification == "cui"
};

@id("external-service-deny-cui-storage")
forbid (
  principal is Nabla::ExternalService,
  action,
  resource is Nabla::StorageBucket
) when {
  resource.dataClassification == "cui"
};
