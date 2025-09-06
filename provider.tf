terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  # Remote State Backend in S3 + DynamoDB
  backend "s3" {
    bucket         = "mhaenni-tf-state"         # <- Manuell durch AWS CLI zu erstellen Pfad: C:\Users\march\OneDrive - TBZ\DevOPS-Ecommerce
    key            = "ecommerce/terraform.tfstate"  # <- eindeutiger Pfad/Dateiname
    region         = "us-east-1"                # <- gleiche Region wie dein Lab
    dynamodb_table = "mhaenni-tf-locks"         # <- Tabelle aus AWS CLI Script
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
