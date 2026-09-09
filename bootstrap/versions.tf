terraform {
  # Upper bound matters: ">= 1.16" permits Terraform 2.0, which will not be
  # compatible with this configuration. "~> 1.16" allows 1.16.x and later 1.x
  # while refusing a major version.
  required_version = "~> 1.16"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
