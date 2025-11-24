// =============================================================================
// Nabla Enclave - CMMC Media Protection Policies
// CMMC Level 2 - Media Protection (MP) Family
// =============================================================================

// -----------------------------------------------------------------------------
// MP.L2-3.8.1 - Protect (i.e., physically control and securely store)
// system media containing CUI
// -----------------------------------------------------------------------------

// Storage buckets with CUI must have encryption required
@id("cmmc-mp-3.8.1-storage-encryption")
forbid (
  principal,
  action == Nabla::Action::"write",
  resource is Nabla::StorageBucket
) when {
  resource.dataClassification == "confidential" &&
  !resource.encryptionRequired
};

// -----------------------------------------------------------------------------
// MP.L2-3.8.2 - Limit access to CUI on system media to authorized users
// -----------------------------------------------------------------------------

// Only cleared users can access confidential storage
@id("cmmc-mp-3.8.2-storage-clearance")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::StorageBucket
) when {
  resource.dataClassification == "confidential" &&
  (principal.clearanceLevel == "public")
};

// Only admins can access restricted storage
@id("cmmc-mp-3.8.2-restricted-storage")
forbid (
  principal is Nabla::User,
  action,
  resource is Nabla::StorageBucket
) when {
  resource.dataClassification == "restricted"
} unless {
  principal in Nabla::Group::"Administrators"
};

// -----------------------------------------------------------------------------
// MP.L2-3.8.3 - Sanitize or destroy system media containing CUI before
// disposal or release
// -----------------------------------------------------------------------------

// Deletion of storage objects requires admin approval
@id("cmmc-mp-3.8.3-object-delete-admin")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"delete",
  resource is Nabla::StorageObject
) unless {
  principal in Nabla::Group::"Administrators" &&
  principal.mfaVerified
};

// Deletion of buckets requires admin with MFA
@id("cmmc-mp-3.8.3-bucket-delete")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"delete",
  resource is Nabla::StorageBucket
) unless {
  principal in Nabla::Group::"Administrators" &&
  principal.mfaVerified
};

// -----------------------------------------------------------------------------
// MP.L2-3.8.7 - Control the use of removable media on system components
// Export operations are controlled as "removable media" equivalent
// -----------------------------------------------------------------------------

// Export from storage requires MFA and elevated clearance
@id("cmmc-mp-3.8.7-storage-export")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"export",
  resource is Nabla::StorageBucket
) when {
  !principal.mfaVerified ||
  principal.clearanceLevel == "public"
};

@id("cmmc-mp-3.8.7-object-export")
forbid (
  principal is Nabla::User,
  action == Nabla::Action::"export",
  resource is Nabla::StorageObject
) when {
  !principal.mfaVerified
};

// -----------------------------------------------------------------------------
// MP.L2-3.8.9 - Protect the confidentiality of backup CUI at storage
// locations
// -----------------------------------------------------------------------------

// Backup bucket access is restricted to data service accounts and admins
@id("cmmc-mp-3.8.9-backup-sa-only")
forbid (
  principal is Nabla::User,
  action,
  resource == Nabla::StorageBucket::"minio-backups"
) unless {
  principal in Nabla::Group::"Administrators" &&
  principal.mfaVerified
};

@id("cmmc-mp-3.8.9-backup-sa-access")
permit (
  principal in Nabla::Group::"DataServiceAccounts",
  action,
  resource == Nabla::StorageBucket::"minio-backups"
);
