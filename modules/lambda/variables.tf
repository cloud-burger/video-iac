variable "name" {
  type = string
}

variable "source_code_hash" {
  default = ""
}

variable "source_bucket" {
  type = string
}

variable "source_key" {
  type = string
}

variable "project" {
  type = string
}

variable "environment_variables" {
  default = {}
}

variable "tags" {
  default = {}
}

variable "timeout" {
  default = "5"
}

variable "memory_size" {
  default = "256"
}

variable "handler" {
  default = ""
}

variable "lambda_role" {
  default = ""
}

variable "subnet_ids" {
  default = []
}

variable "security_group_ids" {
  default = []
}

variable "layers" {
  default = []
}

variable "runtime" {
  default = "nodejs20.x"
}