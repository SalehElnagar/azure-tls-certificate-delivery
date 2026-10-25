mock_provider "azurerm" {
  override_during = plan
  mock_resource "azurerm_storage_container" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-approved-state/providers/Microsoft.Storage/storageAccounts/stapprovedstate/blobServices/default/containers/mvp-tls-example"
    }
  }
}
variables {
  subscription_id    = "00000000-0000-0000-0000-000000000000"
  storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-approved-state/providers/Microsoft.Storage/storageAccounts/stapprovedstate"
  container_name     = "mvp-tls-example"
  operator_object_id = "11111111-1111-1111-1111-111111111111"
}
run "new_container_is_private" {
  command = plan
  assert {
    condition     = azurerm_storage_container.lab_state.container_access_type == "private"
    error_message = "Lab state must never be an anonymous public container."
  }
  assert {
    condition = (
      azurerm_role_assignment.state_operator.scope == "${var.storage_account_id}/blobServices/default/containers/${var.container_name}" &&
      azurerm_role_assignment.state_operator.role_definition_name == "Storage Blob Data Contributor" &&
      azurerm_role_assignment.state_operator.principal_id == var.operator_object_id &&
      azurerm_role_assignment.state_operator.principal_type == "User"
    )
    error_message = "State access must be granted only to the approved operator at the exact lab container, never the account or another principal."
  }
}
run "existing_unrelated_container_names_are_rejected" {
  command = plan
  variables { container_name = "existing-production-state" }
  expect_failures = [var.container_name]
}
