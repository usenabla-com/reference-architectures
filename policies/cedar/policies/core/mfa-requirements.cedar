// =============================================================================
// Nabla Enclave - MFA Requirement Policies
// CMMC IA.L2-3.5.3 - Multi-factor authentication for privileged access
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: MFA Required for Restricted Resources
// Access to restricted data classification requires MFA verification
// -----------------------------------------------------------------------------
@id("mfa-restricted-resources")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Application
) when {
  resource.dataClassification == "restricted" &&
  !principal.mfaVerified
};

@id("mfa-restricted-db")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Database
) when {
  resource.dataClassification == "restricted" &&
  !principal.mfaVerified
};

@id("mfa-restricted-storage")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::StorageBucket
) when {
  resource.dataClassification == "restricted" &&
  !principal.mfaVerified
};

// -----------------------------------------------------------------------------
// POLICY: MFA Required for Administrative Actions
// All admin actions require MFA regardless of resource classification
// -----------------------------------------------------------------------------
@id("mfa-admin-actions")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"admin",
  resource
) when {
  !principal.mfaVerified
};

// -----------------------------------------------------------------------------
// POLICY: MFA Required for Delete Operations
// Delete operations always require MFA verification
// -----------------------------------------------------------------------------
@id("mfa-delete-operations")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"delete",
  resource
) when {
  !principal.mfaVerified
};

// -----------------------------------------------------------------------------
// POLICY: MFA Required for Data Export
// Exporting data requires MFA to prevent unauthorized data exfiltration
// CMMC MP.L2-3.8.2 - Limit CUI access
// -----------------------------------------------------------------------------
@id("mfa-export-operations")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"export",
  resource
) when {
  !principal.mfaVerified
};

// -----------------------------------------------------------------------------
// POLICY: MFA Required for Confidential Data Write
// Writing to confidential resources requires MFA
// -----------------------------------------------------------------------------
@id("mfa-confidential-write")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"write",
  resource is Nabla::Application
) when {
  resource.dataClassification == "confidential" &&
  !principal.mfaVerified
};

@id("mfa-confidential-db-write")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"write",
  resource is Nabla::DatabaseTable
) when {
  !principal.mfaVerified
};
