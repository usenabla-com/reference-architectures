// =============================================================================
// Nabla Enclave - Secrets Management Policies
// OpenBao access control - Restricted classification
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: OpenBao Admin Access Only
// OpenBao is restricted - only administrators can access directly
// Applications use service accounts with specific paths
// -----------------------------------------------------------------------------
@id("openbao-admin-only")
permit (
  principal is Nabla::User,
  action,
  resource == Nabla::Application::"openbao"
) when {
  principal in Nabla::Group::"Administrators" &&
  principal.mfaVerified
};

// -----------------------------------------------------------------------------
// POLICY: Deny Non-Admin OpenBao Access
// Explicitly deny all non-admin human access to OpenBao
// -----------------------------------------------------------------------------
@id("openbao-deny-nonadmin")
forbid (
  principal is Nabla::User,
  action,
  resource == Nabla::Application::"openbao"
) unless {
  principal in Nabla::Group::"Administrators"
};

// -----------------------------------------------------------------------------
// POLICY: Service Account Secret Read
// Service accounts can read secrets from OpenBao for their workload
// -----------------------------------------------------------------------------
@id("openbao-sa-read")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"read",
  resource == Nabla::Application::"openbao"
);

// -----------------------------------------------------------------------------
// POLICY: Deny Service Account Secret Write
// Service accounts cannot write secrets - only admin can manage
// -----------------------------------------------------------------------------
@id("openbao-sa-deny-write")
forbid (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"write",
  resource == Nabla::Application::"openbao"
);

@id("openbao-sa-deny-admin")
forbid (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"admin",
  resource == Nabla::Application::"openbao"
);
