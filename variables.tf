variable "application_id" {
  type        = string
  description = "Application ID for which client secrets shall be managed."
  validation {
    condition     = startswith(var.application_id, "/applications/")
    error_message = "The application_id  must start with '/applications/'"
  }
}

variable "unit" {
  type        = string
  description = "Unit of validity and overlap. Must be one of minutes, hours or months. Defaults to months."
  default     = "months"
  validation {
    condition     = contains(["minutes", "hours", "months"], var.unit)
    error_message = "Invalid unit."
  }
}

variable "validity" {
  type        = number
  description = "The secret validity. Can't be more than 24c months"
  default     = 24

  validation {
    condition     = var.validity > 0
    error_message = "Validity must be positive."
  }
}

variable "overlap" {
  type        = number
  description = "Overlap where both secrets are valid simultaneously."
  default     = 3

  validation {
    condition     = var.overlap > 0
    error_message = "Overlap must be positive."
  }
}

variable "date_format" {
  type        = string
  description = "Date format used in the secret description for the 'not_before' entry"
  default     = "YYYY-MM-DD"
}

variable "jitter" {
  type        = string
  description = "Duration for compensating plan to apply time difference for determining *_after_start. Must be a valid 'timeadd()' duration."
  default     = "2m"
}
