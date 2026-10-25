mock_provider "azurerm" {
  override_during = plan
  mock_data "azurerm_client_config" {
    defaults = { tenant_id = "00000000-0000-0000-0000-000000000010" }
  }
  mock_resource "azurerm_dns_zone" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/dnsZones/tls-lab.example.com" }
  }
  mock_resource "azurerm_virtual_network" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test" }
  }
  mock_resource "azurerm_subnet" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/test" }
  }
  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/test"
      principal_id = "00000000-0000-0000-0000-000000000011"
      client_id    = "00000000-0000-0000-0000-000000000012"
    }
  }
  mock_resource "azurerm_key_vault" {
    defaults = {
      id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/kv-test"
      vault_uri = "https://kv-test.vault.azure.net/"
    }
  }
  mock_resource "azurerm_private_dns_zone" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net" }
  }
  mock_resource "azurerm_storage_account" {
    defaults = {
      id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/sttest"
      primary_blob_endpoint  = "https://sttest.blob.core.windows.net/"
      primary_queue_endpoint = "https://sttest.queue.core.windows.net/"
      primary_table_endpoint = "https://sttest.table.core.windows.net/"
    }
  }
  mock_resource "azurerm_service_plan" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Web/serverFarms/plan-test" }
  }
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test" }
  }
  mock_resource "azurerm_application_insights" {
    defaults = {
      id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Insights/components/appi-test"
      connection_string = "InstrumentationKey=00000000-0000-0000-0000-000000000099;IngestionEndpoint=https://example.com/"
    }
  }
}
variables {
  verifier_ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADA5"
  verifier_image_version  = "24.04.202610010"
  subscription_id         = "00000000-0000-0000-0000-000000000000"
  name                    = "tls-test-lab"
  location                = "canadacentral"
  zone_name               = "tls-lab.example.com"
  owner                   = "platform"
  expires_at              = "2026-10-20T18:00:00Z"
  operator_cidr           = "192.0.2.10/32"
  operator_object_ids     = ["00000000-0000-0000-0000-000000000013"]
  entra_client_id         = "00000000-0000-0000-0000-000000000014"
  acme_contact            = "platform@example.com"
}
run "private_vault_and_scoped_issuer" {
  command = plan
  assert {
    condition     = !azurerm_key_vault.certificates.public_network_access_enabled && azurerm_key_vault.certificates.purge_protection_enabled && azurerm_key_vault.certificates.rbac_authorization_enabled && azurerm_key_vault.certificates.network_acls[0].default_action == "Deny" && azurerm_key_vault.certificates.network_acls[0].bypass == "AzureServices"
    error_message = "The private RBAC vault must permit the documented trusted-service certificate integration and retain recovery protection."
  }
  assert {
    condition     = azurerm_role_assignment.issuer_dns.scope == azurerm_dns_zone.lab.id && azurerm_role_assignment.gateway_vault.scope == azurerm_key_vault.certificates.id
    error_message = "DNS and gateway permissions must be bound to the lab zone/vault."
  }
  assert {
    condition     = azurerm_function_app_flex_consumption.issuer.app_settings["Acmebot__RequireAppRoles"] == "true" && azurerm_function_app_flex_consumption.issuer.auth_settings_v2[0].unauthenticated_action == "Return401"
    error_message = "Anonymous calls must fail before role-protected issuance."
  }
  # Regression: the first authenticated foundation plan exposed this provider default.
  assert {
    condition     = azurerm_function_app_flex_consumption.issuer.webdeploy_publish_basic_authentication_enabled == false && alltrue([for application in azurerm_linux_web_app.demo : application.webdeploy_publish_basic_authentication_enabled == false && application.ftp_publish_basic_authentication_enabled == false])
    error_message = "Issuer and demo deployments must not leave publishing basic authentication enabled."
  }
  assert {
    condition     = azurerm_storage_account.issuer.shared_access_key_enabled == false && azurerm_storage_account.issuer.local_user_enabled == false && azurerm_function_app_flex_consumption.issuer.storage_authentication_type == "UserAssignedIdentity"
    error_message = "Issuer storage must use its managed identity without shared-key or local-user authentication."
  }
  # Regression: a nonempty exact connection string overrides the identity-based host settings.
  assert {
    condition     = lookup(azurerm_function_app_flex_consumption.issuer.app_settings, "AzureWebJobsStorage", null) == "" && azurerm_function_app_flex_consumption.issuer.app_settings["AzureWebJobsStorage__credential"] == "managedidentity" && azurerm_function_app_flex_consumption.issuer.app_settings["AzureWebJobsStorage__clientId"] == azurerm_user_assigned_identity.issuer.client_id
    error_message = "The provider-generated host connection must be explicitly empty so the selected managed identity is used."
  }
}
run "app_routes_have_distinct_response_labels" {
  command = plan
  assert {
    condition     = alltrue([for name, application in azurerm_linux_web_app.demo : try(application.app_settings["LAB_APP_NAME"] == name, false)])
    error_message = "Both synthetic backends must identify their own routes so HTTP checks can detect a wrong backend."
  }
}
run "reject_unbounded_operator_network" {
  command = plan
  variables { operator_cidr = "0.0.0.0/0" }
  expect_failures = [var.operator_cidr]
}
