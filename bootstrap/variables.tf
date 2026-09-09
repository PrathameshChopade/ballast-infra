variable "region" {
  description = "AWS region for the state bucket. Kept with the rest of Ballast in ap-south-1."
  type        = string
  default     = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Region must look like ap-south-1."
  }
}
