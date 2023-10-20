terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      "Environment" = var.environment
      "Region"      = var.region
    }
  }
}

