variable "region" {
  type = string
}
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


variable "db_secret_arn" {
  type = string
}


variable "db_reader_endpoint" {
  type = string
}



variable "db_writer_endpoint" {
  type = string
}

variable "db_name" {
  type = string
}

variable "min_task_count" {
  type = number
}

variable "max_task_count" {
  type = number
}





