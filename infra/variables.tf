variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westeurope"
}

variable "prefix" {
  description = "Name prefix (shared subscription, so names include the owner)"
  type        = string
  default     = "hilal-restauranty"
}

variable "budget_amount" {
  description = "Monthly budget (billing currency) for all resources tagged owner=hilal"
  type        = number
  default     = 150
}

variable "budget_alert_email" {
  description = "Where budget alerts are sent (set in terraform.tfvars, not committed)"
  type        = string
}

variable "aks_enabled" {
  description = "Set to false in the evening to delete both clusters and save cost"
  type        = bool
  default     = true
}