// =============================================================================
// Nabla Enclave - Default Policies
// Zero Trust: Deny by default, explicit allow only
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: Default Deny
// All requests are denied unless explicitly permitted by another policy
// This is the foundation of Zero Trust architecture
// -----------------------------------------------------------------------------
@id("default-deny")
forbid (
  principal,
  action,
  resource
);
