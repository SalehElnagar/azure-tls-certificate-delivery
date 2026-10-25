output "name_servers" { value = azurerm_dns_zone.lab.name_servers }
output "edge_inputs" {
  description = "Private operational handoff: do not publish actual values. No certificate or PFX is read."
  value = {
    resource_group_name = azurerm_resource_group.lab.name
    location            = azurerm_resource_group.lab.location
    gateway_subnet_id   = azurerm_subnet.gateway.id
    gateway_identity_id = azurerm_user_assigned_identity.gateway.id
    vault_uri           = azurerm_key_vault.certificates.vault_uri
    dns_zone_name       = azurerm_dns_zone.lab.name
    workspace_id        = azurerm_log_analytics_workspace.lab.id
    backend_fqdns       = { for key, app in azurerm_linux_web_app.demo : key => app.default_hostname }
  }
  sensitive = true
}

output "operation_targets" {
  sensitive = true
  value = {
    resource_group     = azurerm_resource_group.lab.name
    issuer_app         = azurerm_function_app_flex_consumption.issuer.name
    verifier_vm        = azurerm_linux_virtual_machine.verifier.name
    verifier_client_id = azurerm_user_assigned_identity.verifier.client_id
    vault_uri          = azurerm_key_vault.certificates.vault_uri
    backend_apps       = { for key, app in azurerm_linux_web_app.demo : key => app.name }
  }
}
