variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "log_analytics_workspace_id" { type = string }
variable "acr_id" { type = string }

variable "system_vm_size" { type = string }
variable "system_node_count" {
  type    = number
  default = 2
}
variable "system_only_critical_addons" {
  description = "Taint the system pool so only Kubernetes components run there"
  type        = bool
  default     = false
}
variable "zones" {
  type    = list(string)
  default = []
}

variable "user_pool_enabled" {
  type    = bool
  default = false
}
variable "user_vm_size" {
  type    = string
  default = null
}
variable "user_min_count" {
  type    = number
  default = 3
}
variable "user_max_count" {
  type    = number
  default = 4
}

variable "eso_identity_id" {
  description = "ID of the managed identity External Secrets Operator uses in this cluster"
  type        = string
}
