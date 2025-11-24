// =============================================================================
// Nabla Enclave - Observability Application Policies
// Grafana dashboards and Gatus status page access
// =============================================================================

// -----------------------------------------------------------------------------
// POLICY: Grafana Access - Developers and Admins
// Grafana monitoring dashboards for operations visibility
// -----------------------------------------------------------------------------
@id("grafana-admin-full")
permit (
  principal in Nabla::Group::"Administrators",
  action,
  resource == Nabla::Application::"grafana"
);

@id("grafana-developer-read")
permit (
  principal in Nabla::Group::"Developers",
  action == Nabla::Action::"read",
  resource == Nabla::Application::"grafana"
);

@id("grafana-developer-connect")
permit (
  principal in Nabla::Group::"Developers",
  action == Nabla::Action::"connect",
  resource == Nabla::Application::"grafana"
);

@id("grafana-auditor-read")
permit (
  principal in Nabla::Group::"Auditors",
  action == Nabla::Action::"read",
  resource == Nabla::Application::"grafana"
);

@id("grafana-auditor-connect")
permit (
  principal in Nabla::Group::"Auditors",
  action == Nabla::Action::"connect",
  resource == Nabla::Application::"grafana"
);

// -----------------------------------------------------------------------------
// POLICY: Gatus Status Page - Public Internal Access
// Status page is accessible to all authenticated users
// Public classification means no MFA required
// -----------------------------------------------------------------------------
@id("gatus-user-read")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"read",
  resource == Nabla::Application::"gatus"
);

@id("gatus-user-connect")
permit (
  principal is Nabla::User,
  action == Nabla::Action::"connect",
  resource == Nabla::Application::"gatus"
);

// -----------------------------------------------------------------------------
// POLICY: Observability Admin Actions
// Only admins can configure observability tools
// -----------------------------------------------------------------------------
@id("observability-admin-grafana")
permit (
  principal in Nabla::Group::"Administrators",
  action == Nabla::Action::"admin",
  resource == Nabla::Application::"grafana"
);

@id("observability-admin-gatus")
permit (
  principal in Nabla::Group::"Administrators",
  action == Nabla::Action::"admin",
  resource == Nabla::Application::"gatus"
);
