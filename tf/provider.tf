terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.8.0"
    }
  }

  # Partial configuration - update with your prefered backend choice
  backend "s3" {
    key = "ses-forwarder"
  }
}

provider "aws" {
  region = var.region
}