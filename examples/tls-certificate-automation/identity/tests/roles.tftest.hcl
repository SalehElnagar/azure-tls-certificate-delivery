mock_provider "azuread" {
  override_during = plan
  mock_resource "azuread_application" {
    defaults = {
      id        = "/applications/00000000-0000-0000-0000-000000000001"
      client_id = "00000000-0000-0000-0000-000000000002"
    }
  }
  mock_resource "azuread_service_principal" {
    defaults = { object_id = "00000000-0000-0000-0000-000000000003" }
  }
}
variables {
  tenant_id           = "00000000-0000-0000-0000-000000000000"
  name                = "mvp-tls-example"
  owner_object_id     = "00000000-0000-0000-0000-000000000004"
  operator_object_ids = ["00000000-0000-0000-0000-000000000004"]
}
run "only_approved_operators_can_issue" {
  command = plan
  assert {
    condition     = azuread_service_principal.issuer_api.app_role_assignment_required && length(azuread_application.issuer_api.app_role) == 1 && toset([for role in azuread_application.issuer_api.app_role : role.value]) == toset(["Acmebot.IssueCertificate"])
    error_message = "Require operator assignment and issue-only authority; do not grant revocation."
  }
  assert {
    condition     = length(azuread_app_role_assignment.operator) == length(var.operator_object_ids) && azuread_application.issuer_api.sign_in_audience == "AzureADMyOrg"
    error_message = "Keep the API single-tenant and assignments bound to the explicit operator set."
  }
}
run "reject_empty_operator_set" {
  command = plan
  variables { operator_object_ids = [] }
  expect_failures = [var.operator_object_ids]
}
