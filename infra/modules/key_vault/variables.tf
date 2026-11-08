variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "tenant_id" { type = string }
variable "admin_object_id" {
  description = "Identity that may manage secrets (the person running Terraform)"
  type        = string
}
