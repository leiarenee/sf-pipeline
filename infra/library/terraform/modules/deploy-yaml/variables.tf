variable "namespace" {
  type        = string
  default     = ""
}

variable "application_name" {
  type        = string
  default     = "app"
}

variable "source_folder" {
  type        = string
  default     = "src"
}

variable "deployment_type" {
  type        = string
  description = "Deployment type for descriptive purpose."
  default    = ""
}