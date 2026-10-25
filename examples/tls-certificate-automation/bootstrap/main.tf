terraform {
  required_version = "= 1.14.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "= 4.81.0"
    }
  }
  # Bootstrap state must use an explicitly approved private path outside Git.
  backend "local" {}
}
provider "azurerm" {
  subscription_id                 = var.subscription_id
  resource_provider_registrations = "none"
  storage_use_azuread             = true
  features {}
}
variable "subscription_id" { type = string }
variable "storage_account_id" { type = string }
variable "operator_object_id" {
  type = string
  validation {
    condition     = can(regex("^[a-fA-F0-9]{8}(-[a-fA-F0-9]{4}){3}-[a-fA-F0-9]{12}$", var.operator_object_id))
    error_message = "Use the explicit approved operator's Entra object ID."
  }
}
variable "container_name" {
  type = string
  validation {
    condition     = can(regex("^mvp-tls-[a-z0-9-]+$", var.container_name))
    error_message = "Create only a new mvp-tls-prefixed container for this lab."
  }
}
resource "azurerm_storage_container" "lab_state" {
  name                  = var.container_name
  storage_account_id    = var.storage_account_id
  container_access_type = "private"
}

# ARM ownership of a container does not grant access to its state blobs.
resource "azurerm_role_assignment" "state_operator" {
  scope                = azurerm_storage_container.lab_state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.operator_object_id
  principal_type       = "User"
}
