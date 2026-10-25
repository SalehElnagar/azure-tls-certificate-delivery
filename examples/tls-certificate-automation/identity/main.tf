terraform {
  required_version = "= 1.14.7"
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "= 3.7.0"
    }
  }
  backend "azurerm" {}
}
provider "azuread" {
  tenant_id = var.tenant_id
  use_cli   = true
}
variable "tenant_id" { type = string }
variable "name" { type = string }
variable "owner_object_id" { type = string }
variable "operator_object_ids" {
  type = set(string)
  validation {
    condition     = length(var.operator_object_ids) > 0
    error_message = "Assign only explicit approved operators."
  }
}
locals {
  scope_id      = uuidv5("url", "https://example.com/mvp-tls/${var.name}/user_impersonation")
  issue_role_id = uuidv5("url", "https://example.com/mvp-tls/${var.name}/issue")
}
resource "azuread_application" "issuer_api" {
  display_name            = "${var.name}-issuer-api"
  sign_in_audience        = "AzureADMyOrg"
  prevent_duplicate_names = true
  owners                  = [var.owner_object_id]
  api {
    requested_access_token_version = 2
    oauth2_permission_scope {
      id                         = local.scope_id
      enabled                    = true
      type                       = "Admin"
      value                      = "user_impersonation"
      admin_consent_display_name = "Access the TLS lab issuer as the signed-in operator"
      admin_consent_description  = "Call only this lab API; certificate issuance also requires its issue role."
    }
  }
  app_role {
    id                   = local.issue_role_id
    allowed_member_types = ["User"]
    display_name         = "Issue lab certificates"
    description          = "Issue and manually renew certificates in this lab."
    enabled              = true
    value                = "Acmebot.IssueCertificate"
  }
  # The separate identifier resource uses the generated client ID; it owns this field.
  lifecycle { ignore_changes = [identifier_uris] }
}
resource "azuread_application_identifier_uri" "issuer_api" {
  application_id = azuread_application.issuer_api.id
  identifier_uri = "api://${azuread_application.issuer_api.client_id}"
}
resource "azuread_application_pre_authorized" "azure_cli" {
  application_id       = azuread_application.issuer_api.id
  authorized_client_id = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"
  permission_ids       = [local.scope_id]
}
resource "azuread_service_principal" "issuer_api" {
  client_id                    = azuread_application.issuer_api.client_id
  app_role_assignment_required = true
  owners                       = [var.owner_object_id]
}
resource "azuread_app_role_assignment" "operator" {
  for_each            = var.operator_object_ids
  app_role_id         = local.issue_role_id
  principal_object_id = each.value
  resource_object_id  = azuread_service_principal.issuer_api.object_id
}
output "foundation_auth" {
  sensitive = true
  value = {
    entra_client_id     = azuread_application.issuer_api.client_id
    operator_object_ids = tolist(var.operator_object_ids)
    token_scope         = "api://${azuread_application.issuer_api.client_id}/user_impersonation"
  }
}
