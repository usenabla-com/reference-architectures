// =============================================================================
// Nabla Enclave - Code-Server Application Policies
// VS Code in browser for development workflows
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: Developer Code-Server Access
// All developers can use code-server for development
// -----------------------------------------------------------------------------
@id("codeserver-developer-access")
permit (
  principal in Nabla::Group::"Developers",
  action == Nabla::Action::"connect",
  resource == Nabla::Application::"code-server"
);

@id("codeserver-developer-execute")
permit (
  principal in Nabla::Group::"Developers",
  action == Nabla::Action::"execute",
  resource == Nabla::Application::"code-server"
);

// -----------------------------------------------------------------------------
// POLICY: Administrator Code-Server Access
// Admins have full access to code-server
// -----------------------------------------------------------------------------
@id("codeserver-admin-access")
permit (
  principal in Nabla::Group::"Administrators",
  action,
  resource == Nabla::Application::"code-server"
);

// -----------------------------------------------------------------------------
// POLICY: Code-Server Service Account Access
// Code-server workload can access its own namespace resources
// -----------------------------------------------------------------------------
@id("codeserver-sa-namespace")
permit (
  principal is Nabla::ServiceAccount,
  action == Nabla::Action::"read",
  resource is Nabla::ConfigMap
) when {
  principal.workload == "code-server" &&
  principal.namespace == "workloads"
};
