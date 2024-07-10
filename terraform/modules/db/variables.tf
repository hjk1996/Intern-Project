variable "region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "db_name" {
  type = string
}


variable "vpc_id" {
  type = string
}


variable "db_private_subnet_ids" {
  type = list(string)
}


variable "db_instance_class" {
  type = string
}


variable "db_password" {
  type      = string
  sensitive = true
}

variable "cidr_block" {
  type = string
}





