
variable "project_name" {
  type = string
}


variable "region" {
  type = string
}

variable "number_of_azs" {
  type = number
}


variable "enable_vpc_interface_endpoint" {
  type = bool
}

variable "interface_endpoint_service_names" {
  type    = list(string)
  default = ["secretsmanager", "logs", "ecr.dkr"]
}


variable "cidr_block" {
  type = string
}

