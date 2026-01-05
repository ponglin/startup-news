# Terraform variables for Startup News platform

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "Project ID must be a valid GCP project ID."
  }
}

variable "region" {
  description = "GCP Region for resources"
  type        = string
  default     = "asia-northeast1"
  

variable "gemini_api_key" {
  description = "Google Gemini API Key for AI processing"
  type        = string
  sensitive   = true
  default     = ""
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "enable_monitoring" {
  description = "Enable Cloud Monitoring for functions"
  type        = bool
  default     = true
}

variable "function_memory" {
  description = "Memory allocation for Cloud Function in MB"
  type        = number
  default     = 256
  validation {
    condition     = var.function_memory >= 128 && var.function_memory <= 4096
    error_message = "Memory must be between 128 and 4096 MB."
  }
}

variable "function_timeout" {
  description = "Timeout for Cloud Function in seconds"
  type        = number
  default     = 540
  validation {
    condition     = var.function_timeout >= 60 && var.function_timeout <= 540
    error_message = "Timeout must be between 60 and 540 seconds."
  }
}

variable "labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default = {
    application = "startup-news"
    managed_by  = "terraform"
  }
}
