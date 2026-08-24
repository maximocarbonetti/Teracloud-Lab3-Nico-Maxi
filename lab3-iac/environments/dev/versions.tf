# required_version de terraform + required_providers (aws)

terraform {
  required_version = ">= 1.10.0" # necesario para el lock nativo del backend S3

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
