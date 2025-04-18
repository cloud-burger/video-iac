variable "environment" {
  default = "prod"
}

variable "project" {
  default = "video-converter"
}

variable "commit_hash" {
  default = ""
}

variable "region" {
  default = "us-east-1"
}


variable "database_password" {
  default = "converter"
}

variable "database_instance_class" {
  default = "db.t3.micro"
}

variable "database_name" {
  default = "converter"
}

variable "database_username" {
  default = "converter"
}
