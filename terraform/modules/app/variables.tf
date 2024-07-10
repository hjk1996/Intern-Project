variable "project_name" {
  type = string

}

variable "log_group_arn" {
  type = string
}


variable "log_group_name" {
  type = string
}


variable "vpc_id" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "app_port" {
  type = number
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "app_subnet_ids" {
  type = list(string)
}


variable "db_cluster_identifier" {
  type = string
}
