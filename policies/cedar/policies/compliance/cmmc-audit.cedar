// =============================================================================
// Nabla Enclave - CMMC Audit and Accountability Policies
// CMMC Level 2 - Audit and Accountability (AU) Family
// =============================================================================

// -----------------------------------------------------------------------------
// AU.L2-3.3.1 - Create and retain system audit logs to enable monitoring,
// analysis, investigation, and reporting
// -----------------------------------------------------------------------------

// Auditors can read all audit logs
@id("cmmc-au-3.3.1-auditor-read")
permit (
  principal in Nabla::Group::"Auditors",
  action == Nabla::Action::"read",
  resource is Nabla::AuditLog
);

// Admins can also access audit logs
@id("cmmc-au-3.3.1-admin-read")
permit (
  principal in Nabla::Group::"Administrators",
  action == Nabla::Action::"read",
  resource is Nabla::AuditLog
);

// -----------------------------------------------------------------------------
// AU.L2-3.3.2 - Ensure actions can be traced to individual users
// -----------------------------------------------------------------------------

// Users without valid session cannot perform auditable actions
@id("cmmc-au-3.3.2-traceable-actions")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"write",
  resource
) when {
  principal.sessionId == ""
};

@id("cmmc-au-3.3.2-traceable-delete")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"delete",
  resource
) when {
  principal.sessionId == ""
};

// -----------------------------------------------------------------------------
// AU.L2-3.3.4 - Alert on audit logging process failures
// Admins can receive and respond to audit alerts
// -----------------------------------------------------------------------------
@id("cmmc-au-3.3.4-admin-alerts")
permit (
  principal in Nabla::Group::"Administrators",
  action == Nabla::Action::"audit",
  resource is Nabla::AuditLog
);

// -----------------------------------------------------------------------------
// AU.L2-3.3.8 - Protect audit information from unauthorized access,
// modification, and deletion
// -----------------------------------------------------------------------------

// Deny modification of audit logs
@id("cmmc-au-3.3.8-audit-immutable")
forbid (
  principal,
  action == Nabla::Action::"write",
  resource is Nabla::AuditLog
);

// Deny deletion of audit logs
@id("cmmc-au-3.3.8-audit-no-delete")
forbid (
  principal,
  action == Nabla::Action::"delete",
  resource is Nabla::AuditLog
);

// Only auditors and admins can read audit logs
@id("cmmc-au-3.3.8-audit-read-restricted")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"read",
  resource is Nabla::AuditLog
) unless {
  principal in Nabla::Group::"Auditors" ||
  principal in Nabla::Group::"Administrators"
};

// Protect audit log storage bucket
@id("cmmc-au-3.3.8-audit-storage-protect")
forbid (
  principal,
  action == Nabla::Action::"write",
  resource == Nabla::StorageBucket::"minio-audit-logs"
) unless {
  principal in Nabla::Group::"DataServiceAccounts"
};

@id("cmmc-au-3.3.8-audit-storage-no-delete")
forbid (
  principal,
  action == Nabla::Action::"delete",
  resource == Nabla::StorageBucket::"minio-audit-logs"
);

// -----------------------------------------------------------------------------
// AU.L2-3.3.9 - Limit management of audit logging functionality to
// authorized individuals
// -----------------------------------------------------------------------------

// Only admins can administer audit infrastructure
@id("cmmc-au-3.3.9-audit-admin-only")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"admin",
  resource is Nabla::AuditLog
) unless {
  principal in Nabla::Group::"Administrators"
};
