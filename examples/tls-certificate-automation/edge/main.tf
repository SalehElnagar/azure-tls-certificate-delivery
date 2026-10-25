terraform {
  required_version = "= 1.14.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.81.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  features {}
}

locals {
  tags  = { project = "mvp-tls-lab", owner = var.owner, expires_at = var.expires_at }
  hosts = toset(["one", "two"])
  # Construct the versionless URI; never fetch certificate secret contents.
  certificate_uris = { for host in local.hosts : host => "${trimsuffix(var.foundation.vault_uri, "/")}/secrets/${var.certificate_names[host]}/" }
}

resource "azurerm_public_ip" "gateway" {
  name                = "pip-${var.name}"
  resource_group_name = var.foundation.resource_group_name
  location            = var.foundation.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_network_security_group" "gateway" {
  name                = "nsg-${var.name}-gateway"
  resource_group_name = var.foundation.resource_group_name
  location            = var.foundation.location
  security_rule {
    name                       = "https"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "gateway-management"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "load-balancer"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "deny-other-inbound"
    priority                   = 4096
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

resource "azurerm_subnet_network_security_group_association" "gateway" {
  subnet_id                 = var.foundation.gateway_subnet_id
  network_security_group_id = azurerm_network_security_group.gateway.id
}

resource "azurerm_application_gateway" "lab" {
  name                = "agw-${var.name}"
  resource_group_name = var.foundation.resource_group_name
  location            = var.foundation.location
  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }
  autoscale_configuration {
    min_capacity = 1
    max_capacity = 2
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [var.foundation.gateway_identity_id]
  }
  gateway_ip_configuration {
    name      = "gateway"
    subnet_id = var.foundation.gateway_subnet_id
  }
  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.gateway.id
  }
  frontend_port {
    name = "https"
    port = 443
  }
  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101S"
  }
  dynamic "ssl_certificate" {
    for_each = local.hosts
    content {
      name                = ssl_certificate.value
      key_vault_secret_id = local.certificate_uris[ssl_certificate.value]
    }
  }
  dynamic "backend_address_pool" {
    for_each = local.hosts
    content {
      name  = backend_address_pool.value
      fqdns = [var.foundation.backend_fqdns[backend_address_pool.value]]
    }
  }
  dynamic "backend_http_settings" {
    for_each = local.hosts
    content {
      name                                = backend_http_settings.value
      cookie_based_affinity               = "Disabled"
      port                                = 443
      protocol                            = "Https"
      request_timeout                     = 30
      pick_host_name_from_backend_address = true
      probe_name                          = backend_http_settings.value
    }
  }
  dynamic "probe" {
    for_each = local.hosts
    content {
      name                                      = probe.value
      protocol                                  = "Https"
      path                                      = "/"
      interval                                  = 30
      timeout                                   = 10
      unhealthy_threshold                       = 3
      pick_host_name_from_backend_http_settings = true
      match { status_code = ["200-399"] }
    }
  }
  dynamic "http_listener" {
    for_each = local.hosts
    content {
      name                           = http_listener.value
      frontend_ip_configuration_name = "public"
      frontend_port_name             = "https"
      protocol                       = "Https"
      host_name                      = "${http_listener.value}.${var.foundation.dns_zone_name}"
      require_sni                    = true
      ssl_certificate_name           = http_listener.value
    }
  }
  dynamic "request_routing_rule" {
    for_each = { one = 100, two = 200 }
    content {
      name                       = request_routing_rule.key
      priority                   = request_routing_rule.value
      rule_type                  = "Basic"
      http_listener_name         = request_routing_rule.key
      backend_address_pool_name  = request_routing_rule.key
      backend_http_settings_name = request_routing_rule.key
    }
  }
  depends_on = [azurerm_subnet_network_security_group_association.gateway]
  tags       = merge(local.tags, { managed_by = "terraform" }, var.certificate_refresh_marker == null ? {} : { certificate_refresh = var.certificate_refresh_marker })
}

resource "azurerm_dns_a_record" "app" {
  for_each            = local.hosts
  name                = each.value
  zone_name           = var.foundation.dns_zone_name
  resource_group_name = var.foundation.resource_group_name
  ttl                 = 300
  records             = [azurerm_public_ip.gateway.ip_address]
  tags                = local.tags
}

resource "azurerm_monitor_diagnostic_setting" "gateway" {
  name                       = "gateway-diagnostics"
  target_resource_id         = azurerm_application_gateway.lab.id
  log_analytics_workspace_id = var.foundation.workspace_id
  enabled_log { category_group = "allLogs" }
  enabled_metric { category = "AllMetrics" }
}
