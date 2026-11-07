variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "germanywestcentral"
}

variable "prefix" {
  description = "Name prefix (shared subscription, so names include the owner)"
  type        = string
  default     = "hilal-restauranty"
}
