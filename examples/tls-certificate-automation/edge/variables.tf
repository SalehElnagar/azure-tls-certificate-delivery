variable "subscription_id" { type = string }
variable "name" { type = string }
variable "owner" { type = string }
variable "expires_at" { type = string }
variable "foundation" {
  type = object({
    resource_group_name = string
    location            = string
    gateway_subnet_id   = string
    gateway_identity_id = string
    vault_uri           = string
    dns_zone_name       = string
    workspace_id        = string
    backend_fqdns       = map(string)
  })
  validation {
    condition     = can(regex("^https://[a-z0-9-]+[.]vault[.]azure[.]net/$", var.foundation.vault_uri)) && alltrue([for key in ["one", "two"] : contains(keys(var.foundation.backend_fqdns), key)])
    error_message = "Supply the reviewed foundation vault URI and both backend FQDNs."
  }
}
variable "certificate_names" {
  type    = map(string)
  default = { one = "app-one", two = "app-two" }
  validation {
    condition     = alltrue([for key in ["one", "two"] : can(regex("^[a-zA-Z0-9-]{1,127}$", var.certificate_names[key]))])
    error_message = "Supply both Key Vault certificate names; versions or paths are not allowed."
  }
}

variable "certificate_refresh_marker" {
  type        = string
  default     = null
  description = "Optional operator-controlled tag marker for an explicit certificate refresh; retain its value after the drill. Ordinary renewal relies on versionless references and gateway polling."
}
