provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "cloud-burger-states"
    key    = "video/prod/apps/notification/terraform.tfstate"
    region = "us-east-1"
  }
}