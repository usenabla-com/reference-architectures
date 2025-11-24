// =============================================================================
// Nabla Enclave - CMMC Access Control Policies
// CMMC Level 2 - Access Control (AC) Family
// =============================================================================

// -----------------------------------------------------------------------------
// AC.L2-3.1.1 - Limit system access to authorized users
// -----------------------------------------------------------------------------

// Only authenticated users with valid sessions can access resources
@id("cmmc-ac-3.1.1-session-required")
forbid (
  principal is Nabla::User,
  action,
  resource
) when {
  principal.sessionId == ""
};

// -----------------------------------------------------------------------------
// AC.L2-3.1.2 - Limit system access to the types of transactions and
// functions that authorized users are permitted to execute
// -----------------------------------------------------------------------------

// Users can only perform actions within their clearance level
@id("cmmc-ac-3.1.2-clearance-restricted")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Application
) when {
  resource.dataClassification == "restricted" &&
  principal.clearanceLevel != "restricted"
};

@id("cmmc-ac-3.1.2-clearance-confidential")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Application
) when {
  resource.dataClassification == "confidential" &&
  (principal.clearanceLevel == "public" || principal.clearanceLevel == "internal")
};

// -----------------------------------------------------------------------------
// AC.L2-3.1.3 - Control the flow of CUI in accordance with approved
// authorizations
// -----------------------------------------------------------------------------

// CUI data can only be accessed by users with appropriate clearance
@id("cmmc-ac-3.1.3-cui-db-access")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::DatabaseTable
) when {
  resource.containsCUI &&
  principal.clearanceLevel == "public"
};

// CUI export requires elevated clearance
@id("cmmc-ac-3.1.3-cui-export")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"export",
  resource is Nabla::DatabaseTable
) when {
  resource.containsCUI &&
  principal.clearanceLevel != "restricted"
};

// -----------------------------------------------------------------------------
// AC.L2-3.1.5 - Employ the principle of least privilege
// -----------------------------------------------------------------------------

// Deny write access to system namespaces for non-admins
@id("cmmc-ac-3.1.5-system-ns-protect")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"write",
  resource is Nabla::Namespace
) when {
  resource.securityTier == "system"
} unless {
  principal in Nabla::Group::"Administrators"
};

// Deny delete on any namespace for non-admins
@id("cmmc-ac-3.1.5-ns-delete-protect")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"delete",
  resource is Nabla::Namespace
) unless {
  principal in Nabla::Group::"Administrators"
};

// -----------------------------------------------------------------------------
// AC.L2-3.1.7 - Prevent non-privileged users from executing privileged
// functions
// -----------------------------------------------------------------------------

// Only admins can perform admin actions
@id("cmmc-ac-3.1.7-admin-actions")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"admin",
  resource
) unless {
  principal in Nabla::Group::"Administrators"
};

// Only admins can access restricted applications
@id("cmmc-ac-3.1.7-restricted-apps")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::Application
) when {
  resource.dataClassification == "restricted"
} unless {
  principal in Nabla::Group::"Administrators"
};

// -----------------------------------------------------------------------------
// AC.L2-3.1.12 - Monitor and control remote access sessions
// -----------------------------------------------------------------------------

// External services have limited access
@id("cmmc-ac-3.1.12-external-readonly")
forbid (
  principal is Nabla::ExternalService,
  action == Nabla::Action::"write",
  resource
);

@id("cmmc-ac-3.1.12-external-no-delete")
forbid (
  principal is Nabla::ExternalService,
  action == Nabla::Action::"delete",
  resource
);

@id("cmmc-ac-3.1.12-external-no-admin")
forbid (
  principal is Nabla::ExternalService,
  action == Nabla::Action::"admin",
  resource
);
