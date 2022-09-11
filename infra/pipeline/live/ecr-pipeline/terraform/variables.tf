variable "repository_name" {
  type = string
  description = "Name of the repository"
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository.Must be one of MUTABLE or IMMUTABLE."
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository (true) or not scanned (false)."
  type        = bool
  default     = true
}

variable "life_cycle_policy" {
  description = "Enables lifecycle policy"
  type        = bool
  default     = true
}

variable "keep_tagged_last_n_images" {
  description = "Keeps only n number of images in the repository."
  type        = number
  default     = 30
}

variable "tagPrefixList" {
  description = "Selection criteria for tagged images lifecycle policy."
  type        = list(string)
  default     = ["v"]
}

variable "expire_untagged_older_than_n_days" {
  description = "Deletes untagged images older than n days."
  type        = number
  default     = 15
}
