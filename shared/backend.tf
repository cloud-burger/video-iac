provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "cloud-burger-states"
    key    = "video/prod/shared/terraform.tfstate"
    region = "us-east-1"
  }
}

data "aws_caller_identity" "current" {}