provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "cloud-burger-states"
    key    = "video/prod/apps/converter/terraform.tfstate"
    region = "us-east-1"
  }
}

data "terraform_remote_state" "iac_state" {
  backend = "s3"

  config = {
    bucket = "cloud-burger-states"
    key    = "prod/iac.tfstate"
    region = "us-east-1"
  }
}

data "aws_caller_identity" "current" {}