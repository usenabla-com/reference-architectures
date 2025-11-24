// =============================================================================
// Nabla Enclave - CMMC Identification and Authentication Policies
// CMMC Level 2 - Identification and Authentication (IA) Family
// =============================================================================

// -----------------------------------------------------------------------------
// IA.L2-3.5.1 - Identify system users, processes, and devices
// -----------------------------------------------------------------------------

// All principals must have proper identification
@id("cmmc-ia-3.5.1-user-identity")
forbid (
  principal is Nabla::User,
  action,
  resource
) when {
  principal.email == ""
};

@id("cmmc-ia-3.5.1-sa-identity")
forbid (
  principal is Nabla::ServiceAccount,
  action,
  resource
) when {
  principal.namespace == "" ||
  principal.workload == ""
};

// -----------------------------------------------------------------------------
// IA.L2-3.5.2 - Authenticate users, processes, and devices
// Session ID validates authentication occurred
// -----------------------------------------------------------------------------

@id("cmmc-ia-3.5.2-session-auth")
forbid (
  principal is Nabla::User,
  action,
  resource
) when {
  principal.sessionId == ""
};

// -----------------------------------------------------------------------------
// IA.L2-3.5.3 - Use multi-factor authentication for local and network
// access to privileged accounts and for network access to non-privileged
// accounts
// -----------------------------------------------------------------------------

// MFA required for all write operations
@id("cmmc-ia-3.5.3-mfa-write")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"write",
  resource
) when {
  !principal.mfaVerified
};

// MFA required for privileged (admin) accounts always
// Only applies to User principals (ServiceAccounts don't have MFA)
@id("cmmc-ia-3.5.3-mfa-admin")
forbid (
  principal is Nabla::User,
  action,
  resource
) when {
  principal in Nabla::Group::"Administrators" &&
  !principal.mfaVerified
};

// MFA required for accessing CUI
@id("cmmc-ia-3.5.3-mfa-cui")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::DatabaseTable
) when {
  resource.containsCUI &&
  !principal.mfaVerified
};

// MFA required for confidential applications
@id("cmmc-ia-3.5.3-mfa-confidential")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Application
) when {
  resource.dataClassification == "confidential" &&
  !principal.mfaVerified
};

// -----------------------------------------------------------------------------
// IA.L2-3.5.7 - Enforce a minimum password complexity and change of
// characters when new passwords are created
// (Handled by Teleport - policy just ensures MFA is in place)
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// IA.L2-3.5.10 - Store and transmit only cryptographically protected
// passwords
// (Infrastructure level - OpenBao handles this)
// Deny direct access to secrets without proper authentication
// -----------------------------------------------------------------------------

@id("cmmc-ia-3.5.10-secret-protection")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Secret
) when {
  !principal.mfaVerified
};

// -----------------------------------------------------------------------------
// IA.L2-3.5.11 - Obscure feedback of authentication information
// (UI level - handled by applications)
// Ensure credentials cannot be read back
// -----------------------------------------------------------------------------

@id("cmmc-ia-3.5.11-no-secret-read")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"read",
  resource is Nabla::Secret
) when {
  resource.type == "kubernetes.io/basic-auth" ||
  resource.type == "kubernetes.io/ssh-auth" ||
  resource.type == "kubernetes.io/tls"
} unless {
  principal in Nabla::Group::"Administrators" &&
  principal.mfaVerified
};
