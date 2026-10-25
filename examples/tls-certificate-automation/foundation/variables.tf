variable "subscription_id" { type = string }
variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,14}[a-z0-9]$", var.name)) && !strcontains(var.name, "--")
    error_message = "Use a lowercase globally unique lab name, 4-16 characters, ending in a letter or digit, without consecutive hyphens."
  }
}
variable "location" { type = string }
variable "zone_name" {
  type = string
  validation {
    condition     = can(regex("^tls-lab[.][a-z0-9.-]+[.][a-z]{2,}$", var.zone_name))
    error_message = "Use only a dedicated tls-lab subzone; the parent domain is outside this example."
  }
}
variable "owner" { type = string }
variable "expires_at" { type = string }
variable "operator_cidr" {
  type = string
  validation {
    condition     = can(cidrnetmask(var.operator_cidr)) && try(tonumber(split("/", var.operator_cidr)[1]) >= 24, false)
    error_message = "Use a bounded IPv4 operator network (/24 or narrower)."
  }
}
variable "operator_object_ids" {
  type = list(string)
  validation {
    condition     = length(var.operator_object_ids) > 0
    error_message = "Explicit operator identities are required."
  }
}
variable "entra_client_id" { type = string }
variable "acme_contact" {
  type      = string
  sensitive = true
}
variable "acme_endpoint" {
  type    = string
  default = "https://acme-staging-v02.api.letsencrypt.org/directory"
  validation {
    condition = contains([
      "https://acme-staging-v02.api.letsencrypt.org/directory",
      "https://acme-v02.api.letsencrypt.org/directory"
    ], var.acme_endpoint)
    error_message = "Use a separately approved Let's Encrypt staging or production directory."
  }
}
variable "verifier_ssh_public_key" {
  type        = string
  description = "Public key only. The verifier has no public IP and denies all inbound traffic; operate through reviewed VM Run Command."
}
variable "verifier_image_version" {
  type = string
  validation {
    condition     = can(regex("^[0-9]+[.][0-9]+[.][0-9]+$", var.verifier_image_version))
    error_message = "Select and review an exact Canonical image version; latest is not accepted."
  }
}
