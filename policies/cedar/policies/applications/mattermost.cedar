// =============================================================================
// Nabla Enclave - Mattermost Application Policies
// Team collaboration and messaging with CUI handling
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: User Mattermost Access
// All authenticated users can access Mattermost for collaboration
// This is the primary CUI communication channel
// -----------------------------------------------------------------------------
@id("mattermost-user-connect")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"connect",
  resource == Nabla::Application::"mattermost"
) when {
  principal.mfaVerified
};

@id("mattermost-user-read")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"read",
  resource == Nabla::Application::"mattermost"
) when {
  principal.mfaVerified
};

@id("mattermost-user-write")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"write",
  resource == Nabla::Application::"mattermost"
) when {
  principal.mfaVerified
};

// -----------------------------------------------------------------------------
// POLICY: Mattermost Database Access
// Mattermost service account needs database access
// -----------------------------------------------------------------------------
@id("mattermost-sa-db")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"connect",
  resource == Nabla::Database::"postgres-main"
) when {
  principal.workload == "mattermost"
};

@id("mattermost-sa-tables-read")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"read",
  resource is Nabla::DatabaseTable
) when {
  principal.workload == "mattermost"
};

@id("mattermost-sa-tables-write")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"write",
  resource is Nabla::DatabaseTable
) when {
  principal.workload == "mattermost"
};

// -----------------------------------------------------------------------------
// POLICY: Mattermost Admin Functions
// Only admins can perform administrative actions on Mattermost
// -----------------------------------------------------------------------------
@id("mattermost-admin")
permit (
  principal in Nabla::Group::"Administrators",
  action == Nabla::Action::"admin",
  resource == Nabla::Application::"mattermost"
);

// -----------------------------------------------------------------------------
// POLICY: Deny Mattermost Data Export Without MFA
// Prevent unauthorized export of CUI from Mattermost
// -----------------------------------------------------------------------------
@id("mattermost-export-mfa")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"export",
  resource == Nabla::Application::"mattermost"
) when {
  !principal.mfaVerified
};
