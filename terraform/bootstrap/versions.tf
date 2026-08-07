terraform {
  required_version = ">= 1.12.2, < 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.54.0"
    }
  }
}
