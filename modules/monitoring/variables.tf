variable "name_prefix" {
  description = "Prefix used in resource names, e.g. aksplat-dev."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the monitoring resources."
  type        = string
}

variable "retention_in_days" {
  description = "Log Analytics data retention in days (30 to 730)."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB. Use -1 for no cap."
  type        = number
  default     = -1
}

variable "action_group_short_name" {
  description = "Short name of the action group (max 12 characters)."
  type        = string

  validation {
    condition     = length(var.action_group_short_name) <= 12
    error_message = "action_group_short_name must be 12 characters or fewer."
  }
}

variable "alert_email_addresses" {
  description = "Email addresses that receive alert notifications."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
