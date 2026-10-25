mock_provider "azurerm" {
  mock_resource "azurerm_public_ip" {
    defaults = {
      id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/publicIPAddresses/gateway"
      ip_address = "192.0.2.20"
    }
  }
  mock_resource "azurerm_network_security_group" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/networkSecurityGroups/gateway" }
  }
  mock_resource "azurerm_application_gateway" {
    defaults = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/applicationGateways/gateway" }
  }
}
variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  name            = "tls-test-lab"
  owner           = "platform"
  expires_at      = "2026-10-20T18:00:00Z"
  foundation = {
    resource_group_name = "rg-test"
    location            = "canadacentral"
    gateway_subnet_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/gateway"
    gateway_identity_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/gateway"
    vault_uri           = "https://kv-test.vault.azure.net/"
    dns_zone_name       = "tls-lab.example.com"
    workspace_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
    backend_fqdns       = { one = "app-one.azurewebsites.net", two = "app-two.azurewebsites.net" }
  }
}
run "both_listeners_follow_versionless_vault_secrets" {
  command = apply
  assert {
    condition     = length(azurerm_application_gateway.lab.http_listener) == 2 && alltrue([for listener in azurerm_application_gateway.lab.http_listener : listener.protocol == "Https" && listener.require_sni])
    error_message = "Both application hostnames need independent SNI HTTPS listeners."
  }
  assert {
    condition     = toset([for cert in azurerm_application_gateway.lab.ssl_certificate : cert.key_vault_secret_id]) == toset(["https://kv-test.vault.azure.net/secrets/app-one/", "https://kv-test.vault.azure.net/secrets/app-two/"])
    error_message = "Version-pinned secrets would prevent following new certificate versions."
  }
}
run "reject_version_in_certificate_name" {
  command = plan
  variables { certificate_names = { one = "app-one/version", two = "app-two" } }
  expect_failures = [var.certificate_names]
}

run "explicit_refresh_marker_is_gateway_only" {
  command = plan
  variables { certificate_refresh_marker = "drill-1" }
  assert {
    condition     = try(azurerm_application_gateway.lab.tags["certificate_refresh"] == "drill-1", false) && !contains(keys(azurerm_public_ip.gateway.tags), "certificate_refresh") && !contains(keys(azurerm_network_security_group.gateway.tags), "certificate_refresh")
    error_message = "An explicit refresh marker must affect only the gateway tag."
  }
}
