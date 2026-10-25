terraform {
  required_version = "= 1.14.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.81.0"
    }
  }
  # Live use requires an approved encrypted remote backend and connected runner.
  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  storage_use_azuread             = true
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = false
    }
  }
}

data "azurerm_client_config" "current" {}

locals {
  tags          = { project = "mvp-tls-lab", owner = var.owner, expires_at = var.expires_at }
  storage_roles = toset(["Storage Blob Data Owner", "Storage Queue Data Contributor", "Storage Table Data Contributor"])
}

resource "azurerm_resource_group" "lab" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_dns_zone" "lab" {
  name                = var.zone_name
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_virtual_network" "lab" {
  name                = "vnet-${var.name}"
  address_space       = ["10.92.0.0/16"]
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_subnet" "gateway" {
  name                 = "gateway"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.92.0.0/24"]
  service_endpoints    = ["Microsoft.Web"]
}

resource "azurerm_subnet" "issuer" {
  name                 = "issuer"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.92.1.0/26"]
  delegation {
    name = "flex-consumption"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.92.2.0/24"]
}

resource "azurerm_user_assigned_identity" "issuer" {
  name                = "id-${var.name}-issuer"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "gateway" {
  name                = "id-${var.name}-gateway"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags
}

resource "azurerm_key_vault" "certificates" {
  name                          = "kv-${var.name}"
  location                      = azurerm_resource_group.lab.location
  resource_group_name           = azurerm_resource_group.lab.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  purge_protection_enabled      = true
  soft_delete_retention_days    = 7
  network_acls {
    default_action = "Deny"
    # Required by the Application Gateway trusted-service integration, including with a private endpoint.
    bypass = "AzureServices"
  }
  tags = local.tags
}

resource "azurerm_private_dns_zone" "vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.lab.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "vault" {
  name                  = "vault-lab-link"
  resource_group_name   = azurerm_resource_group.lab.name
  private_dns_zone_name = azurerm_private_dns_zone.vault.name
  virtual_network_id    = azurerm_virtual_network.lab.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_private_endpoint" "vault" {
  name                = "pe-${var.name}-vault"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  private_service_connection {
    name                           = "vault"
    private_connection_resource_id = azurerm_key_vault.certificates.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
  private_dns_zone_group {
    name                 = "vault"
    private_dns_zone_ids = [azurerm_private_dns_zone.vault.id]
  }
  tags = local.tags
}

resource "azurerm_role_assignment" "issuer_dns" {
  scope                = azurerm_dns_zone.lab.id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.issuer.principal_id
}

resource "azurerm_role_assignment" "issuer_vault" {
  scope                = azurerm_key_vault.certificates.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = azurerm_user_assigned_identity.issuer.principal_id
}

resource "azurerm_role_assignment" "gateway_vault" {
  scope                = azurerm_key_vault.certificates.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.gateway.principal_id
}

resource "azurerm_storage_account" "issuer" {
  name                            = replace("st${var.name}", "-", "")
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  local_user_enabled              = false
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  blob_properties {
    versioning_enabled = true
    delete_retention_policy { days = 7 }
    container_delete_retention_policy { days = 7 }
  }
  tags = local.tags
}

resource "azurerm_storage_container" "package" {
  name                  = "issuer-package"
  storage_account_id    = azurerm_storage_account.issuer.id
  container_access_type = "private"
}

resource "azurerm_role_assignment" "issuer_storage" {
  for_each             = local.storage_roles
  scope                = azurerm_storage_account.issuer.id
  role_definition_name = each.value
  principal_id         = azurerm_user_assigned_identity.issuer.principal_id
}

resource "azurerm_log_analytics_workspace" "lab" {
  name                = "log-${var.name}"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 1
  tags                = local.tags
}

resource "azurerm_application_insights" "issuer" {
  name                         = "appi-${var.name}"
  location                     = azurerm_resource_group.lab.location
  resource_group_name          = azurerm_resource_group.lab.name
  workspace_id                 = azurerm_log_analytics_workspace.lab.id
  application_type             = "web"
  local_authentication_enabled = false
  tags                         = local.tags
}

resource "azurerm_role_assignment" "issuer_metrics" {
  scope                = azurerm_application_insights.issuer.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_user_assigned_identity.issuer.principal_id
}

resource "azurerm_service_plan" "issuer" {
  name                = "plan-${var.name}-issuer"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = local.tags
}

resource "azurerm_function_app_flex_consumption" "issuer" {
  name                                           = "func-${var.name}"
  resource_group_name                            = azurerm_resource_group.lab.name
  location                                       = azurerm_resource_group.lab.location
  service_plan_id                                = azurerm_service_plan.issuer.id
  storage_container_type                         = "blobContainer"
  storage_container_endpoint                     = "${azurerm_storage_account.issuer.primary_blob_endpoint}${azurerm_storage_container.package.name}"
  storage_authentication_type                    = "UserAssignedIdentity"
  storage_user_assigned_identity_id              = azurerm_user_assigned_identity.issuer.id
  runtime_name                                   = "dotnet-isolated"
  runtime_version                                = "10.0"
  maximum_instance_count                         = 2
  instance_memory_in_mb                          = 2048
  virtual_network_subnet_id                      = azurerm_subnet.issuer.id
  https_only                                     = true
  webdeploy_publish_basic_authentication_enabled = false
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.issuer.id]
  }
  site_config {
    minimum_tls_version           = "1.2"
    scm_minimum_tls_version       = "1.2"
    ip_restriction_default_action = "Deny"
    ip_restriction {
      name       = "lab-operator"
      priority   = 100
      action     = "Allow"
      ip_address = var.operator_cidr
    }
    scm_use_main_ip_restriction            = true
    application_insights_connection_string = azurerm_application_insights.issuer.connection_string
  }
  auth_settings_v2 {
    auth_enabled           = true
    require_authentication = true
    unauthenticated_action = "Return401"
    require_https          = true
    default_provider       = "azureactivedirectory"
    active_directory_v2 {
      client_id            = var.entra_client_id
      tenant_auth_endpoint = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
      allowed_audiences    = ["api://${var.entra_client_id}"]
      allowed_identities   = var.operator_object_ids
    }
    login { token_store_enabled = false }
  }
  app_settings = {
    # AzureRM 4.81.0 injects a key-based host connection even with identity-based deployment storage.
    "AzureWebJobsStorage"                       = ""
    "Acmebot__Endpoint"                         = var.acme_endpoint
    "Acmebot__Contacts"                         = var.acme_contact
    "Acmebot__VaultBaseUrl"                     = azurerm_key_vault.certificates.vault_uri
    "Acmebot__Environment"                      = "AzureCloud"
    "Acmebot__ManagedIdentityClientId"          = azurerm_user_assigned_identity.issuer.client_id
    "Acmebot__AzureDns__SubscriptionId"         = var.subscription_id
    "Acmebot__RequireAppRoles"                  = "true"
    "AzureWebJobsStorage__accountName"          = azurerm_storage_account.issuer.name
    "AzureWebJobsStorage__blobServiceUri"       = azurerm_storage_account.issuer.primary_blob_endpoint
    "AzureWebJobsStorage__queueServiceUri"      = azurerm_storage_account.issuer.primary_queue_endpoint
    "AzureWebJobsStorage__tableServiceUri"      = azurerm_storage_account.issuer.primary_table_endpoint
    "AzureWebJobsStorage__credential"           = "managedidentity"
    "AzureWebJobsStorage__clientId"             = azurerm_user_assigned_identity.issuer.client_id
    "APPLICATIONINSIGHTS_AUTHENTICATION_STRING" = "ClientId=${azurerm_user_assigned_identity.issuer.client_id};Authorization=AAD"
  }
  depends_on = [azurerm_role_assignment.issuer_storage, azurerm_role_assignment.issuer_dns, azurerm_role_assignment.issuer_vault, azurerm_private_endpoint.vault]
  tags       = local.tags
}

resource "azurerm_service_plan" "apps" {
  name                = "plan-${var.name}-apps"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  os_type             = "Linux"
  sku_name            = "B1"
  tags                = local.tags
}

resource "azurerm_linux_web_app" "demo" {
  for_each                                       = toset(["one", "two"])
  name                                           = "app-${var.name}-${each.key}"
  resource_group_name                            = azurerm_resource_group.lab.name
  location                                       = azurerm_resource_group.lab.location
  service_plan_id                                = azurerm_service_plan.apps.id
  https_only                                     = true
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  app_settings                                   = { LAB_APP_NAME = each.key }
  site_config {
    app_command_line                  = "gunicorn --bind=0.0.0.0:8000 app:app"
    always_on                         = true
    minimum_tls_version               = "1.2"
    scm_minimum_tls_version           = "1.2"
    ftps_state                        = "Disabled"
    http2_enabled                     = true
    health_check_path                 = "/"
    health_check_eviction_time_in_min = 2
    application_stack { python_version = "3.13" }
    ip_restriction_default_action = "Deny"
    ip_restriction {
      name                      = "gateway-only"
      priority                  = 100
      action                    = "Allow"
      virtual_network_subnet_id = azurerm_subnet.gateway.id
    }
    scm_ip_restriction_default_action = "Deny"
    scm_ip_restriction {
      name       = "lab-operator"
      priority   = 100
      action     = "Allow"
      ip_address = var.operator_cidr
    }
  }
  logs {
    detailed_error_messages = true
    failed_request_tracing  = true
    http_logs {
      file_system {
        retention_in_days = 3
        retention_in_mb   = 25
      }
    }
  }
  tags = local.tags
}

resource "azurerm_monitor_diagnostic_setting" "vault" {
  name                       = "vault-audit"
  target_resource_id         = azurerm_key_vault.certificates.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id
  enabled_log { category_group = "audit" }
  enabled_metric { category = "AllMetrics" }
}

# A private verifier avoids opening the vault firewall for an operator laptop.
resource "azurerm_user_assigned_identity" "verifier" {
  name                = "id-${var.name}-verifier"
  resource_group_name = azurerm_resource_group.lab.name
  location            = azurerm_resource_group.lab.location
  tags                = local.tags
}

resource "azurerm_role_assignment" "verifier_public_certificates" {
  scope                = azurerm_key_vault.certificates.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azurerm_user_assigned_identity.verifier.principal_id
}

# VM Run Command needs explicit outbound HTTPS; do not rely on default egress.
resource "azurerm_subnet" "verifier" {
  name                            = "verifier"
  resource_group_name             = azurerm_resource_group.lab.name
  virtual_network_name            = azurerm_virtual_network.lab.name
  address_prefixes                = ["10.92.3.0/26"]
  default_outbound_access_enabled = false
}

resource "azurerm_public_ip" "verifier_egress" {
  name                = "pip-${var.name}-verifier-egress"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway" "verifier" {
  name                = "nat-${var.name}-verifier"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name            = "Standard"
  tags                = local.tags
}

resource "azurerm_nat_gateway_public_ip_association" "verifier" {
  nat_gateway_id       = azurerm_nat_gateway.verifier.id
  public_ip_address_id = azurerm_public_ip.verifier_egress.id
}

resource "azurerm_subnet_nat_gateway_association" "verifier" {
  subnet_id      = azurerm_subnet.verifier.id
  nat_gateway_id = azurerm_nat_gateway.verifier.id
}

resource "azurerm_network_interface" "verifier" {
  name                = "nic-${var.name}-verifier"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  ip_configuration {
    name                          = "private"
    subnet_id                     = azurerm_subnet.verifier.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = local.tags
}

resource "azurerm_network_security_group" "verifier" {
  name                = "nsg-${var.name}-verifier"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = local.tags
}

resource "azurerm_network_interface_security_group_association" "verifier" {
  network_interface_id      = azurerm_network_interface.verifier.id
  network_security_group_id = azurerm_network_security_group.verifier.id
}

resource "azurerm_linux_virtual_machine" "verifier" {
  name                            = "vm-${var.name}-verifier"
  resource_group_name             = azurerm_resource_group.lab.name
  location                        = azurerm_resource_group.lab.location
  size                            = "Standard_B2ats_v2"
  admin_username                  = "laboperator"
  disable_password_authentication = true
  secure_boot_enabled             = true
  vtpm_enabled                    = true
  network_interface_ids           = [azurerm_network_interface.verifier.id]
  admin_ssh_key {
    username   = "laboperator"
    public_key = var.verifier_ssh_public_key
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.verifier.id]
  }
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = var.verifier_image_version
  }
  depends_on = [azurerm_network_interface_security_group_association.verifier, azurerm_subnet_nat_gateway_association.verifier, azurerm_nat_gateway_public_ip_association.verifier]
  tags       = local.tags
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  for_each                   = toset(["blob", "queue", "table"])
  name                       = "${each.key}-audit"
  target_resource_id         = "${azurerm_storage_account.issuer.id}/${each.key}Services/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.lab.id
  enabled_log { category = "StorageRead" }
  enabled_log { category = "StorageWrite" }
  enabled_log { category = "StorageDelete" }
}
