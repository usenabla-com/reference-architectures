// =============================================================================
// Nabla Enclave - Role-Based Access Control Policies
// Maps Teleport roles to Cedar permissions
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: Administrator Full Access
// Administrators have unrestricted access to all resources
// Maps to Teleport 'admin' role
// -----------------------------------------------------------------------------
@id("admin-full-access")
permit (
  principal in Nabla::Group::"Administrators",
  action,
  resource
);

// -----------------------------------------------------------------------------
// POLICY: Developer Application Access
// Developers can access all applications except restricted ones
// Maps to Teleport 'developer' role
// -----------------------------------------------------------------------------
@id("developer-app-read")
permit (
  principal in Nabla::Group::"Developers",
  action == Nabla::Action::"read",
  resource is Nabla::Application
) when {
  resource.dataClassification != "restricted"
};

@id("developer-app-connect")
permit (
  principal in Nabla::Group::"Developers",
  action == Nabla::Action::"connect",
  resource is Nabla::Application
) when {
  resource.dataClassification != "restricted"
};

@id("developer-app-execute")
permit (
  principal in Nabla::Group::"Developers",
  action == Nabla::Action::"execute",
  resource is Nabla::Application
) when {
  resource.dataClassification != "restricted"
};

// -----------------------------------------------------------------------------
// POLICY: Developer Non-Production Write Access
// Developers can write to non-production environments
// -----------------------------------------------------------------------------
@id("developer-nonprod-write")
permit (
  principal in Nabla::Group::"Developers",
  action == Nabla::Action::"write",
  resource is Nabla::Application
) when {
  resource.environment != "production" &&
  resource.dataClassification != "restricted"
};

// -----------------------------------------------------------------------------
// POLICY: Developer Database Access
// Developers have read access to databases (non-restricted)
// -----------------------------------------------------------------------------
@id("developer-db-read")
permit (
  principal in Nabla::Group::"Developers",
  action == Nabla::Action::"read",
  resource is Nabla::Database
) when {
  resource.dataClassification != "restricted"
};

@id("developer-db-connect")
permit (
  principal in Nabla::Group::"Developers",
  action == Nabla::Action::"connect",
  resource is Nabla::Database
) when {
  resource.dataClassification != "restricted"
};

// -----------------------------------------------------------------------------
// POLICY: Auditor Read-Only Access
// Auditors can read audit logs and compliance reports
// Maps to Teleport 'auditor' role
// -----------------------------------------------------------------------------
@id("auditor-audit-logs")
permit (
  principal in Nabla::Group::"Auditors",
  action == Nabla::Action::"read",
  resource is Nabla::AuditLog
);

@id("auditor-audit-action")
permit (
  principal in Nabla::Group::"Auditors",
  action == Nabla::Action::"audit",
  resource is Nabla::AuditLog
);

@id("auditor-compliance-read")
permit (
  principal in Nabla::Group::"Auditors",
  action == Nabla::Action::"read",
  resource is Nabla::ComplianceReport
);

@id("auditor-compliance-audit")
permit (
  principal in Nabla::Group::"Auditors",
  action == Nabla::Action::"audit",
  resource is Nabla::ComplianceReport
);

// -----------------------------------------------------------------------------
// POLICY: Read-Only Group
// Basic read access to public and internal resources
// -----------------------------------------------------------------------------
@id("readonly-public-access")
permit (
  principal in Nabla::Group::"ReadOnly",
  action == Nabla::Action::"read",
  resource is Nabla::Application
) when {
  resource.dataClassification == "public" ||
  resource.dataClassification == "internal"
};
