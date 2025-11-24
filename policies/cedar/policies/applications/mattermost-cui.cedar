// =============================================================================
// Nabla Enclave - Mattermost CUI Application Policies
// CUI-specific team collaboration with strict access controls
// CMMC AC.L2-3.1.3 - Control CUI flow
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: CUI Mattermost Access - Requires CUI Authorization + MFA
// Only users with cui_authorized trait and MFA can access
// -----------------------------------------------------------------------------
@id("mattermost-cui-user-connect")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"connect",
  resource == Nabla::Application::"mattermost-cui"
) when {
  principal.mfaVerified &&
  principal.cuiAuthorized &&
  (principal.clearanceLevel == "confidential" ||
   principal.clearanceLevel == "restricted")
};

@id("mattermost-cui-user-read")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"read",
  resource == Nabla::Application::"mattermost-cui"
) when {
  principal.mfaVerified &&
  principal.cuiAuthorized &&
  (principal.clearanceLevel == "confidential" ||
   principal.clearanceLevel == "restricted")
};

@id("mattermost-cui-user-write")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"write",
  resource == Nabla::Application::"mattermost-cui"
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
@id("mattermost-cui-deny-unauthorized")
forbid (
  principal is Nabla::User,
  action,
  resource == Nabla::Application::"mattermost-cui"
) when {
  !principal.cuiAuthorized
};

@id("mattermost-cui-deny-no-mfa")
forbid (
  principal is Nabla::User,
  action,
  resource == Nabla::Application::"mattermost-cui"
) when {
  !principal.mfaVerified
};

@id("mattermost-cui-deny-low-clearance")
forbid (
  principal is Nabla::User,
  action,
  resource == Nabla::Application::"mattermost-cui"
) when {
  principal.clearanceLevel == "public" ||
  principal.clearanceLevel == "internal"
};

// -----------------------------------------------------------------------------
// POLICY: Mattermost CUI Service Account Database Access
// -----------------------------------------------------------------------------
@id("mattermost-cui-sa-db")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"connect",
  resource == Nabla::Database::"postgres-cui"
) when {
  principal.workload == "mattermost-cui" &&
  principal.namespace == "workloads-cui"
};

@id("mattermost-cui-sa-tables-read")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"read",
  resource is Nabla::DatabaseTable
) when {
  principal.workload == "mattermost-cui" &&
  principal.namespace == "workloads-cui"
};

@id("mattermost-cui-sa-tables-write")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"write",
  resource is Nabla::DatabaseTable
) when {
  principal.workload == "mattermost-cui" &&
  principal.namespace == "workloads-cui"
};

// -----------------------------------------------------------------------------
// POLICY: CUI Admin Functions - Restricted clearance only
// -----------------------------------------------------------------------------
@id("mattermost-cui-admin")
permit (
  principal in Nabla::Group::"CUIAdministrators",
  action == Nabla::Action::"admin",
  resource == Nabla::Application::"mattermost-cui"
) when {
  principal.mfaVerified &&
  principal.clearanceLevel == "restricted"
};

// -----------------------------------------------------------------------------
// POLICY: Block All Export from CUI Mattermost
// CMMC MP.L2-3.8.2 - Limit CUI access
// -----------------------------------------------------------------------------
@id("mattermost-cui-deny-export")
forbid (
  principal,
  action == Nabla::Action::"export",
  resource == Nabla::Application::"mattermost-cui"
);
