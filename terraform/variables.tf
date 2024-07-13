variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "project_name" {
  type    = string
  default = "intern-project"
}


variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "app"
}


variable "ssh_key_path" {
  type = string
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "slack_webhook_url" {
  type = string
}

variable "slack_channel" {
  type = string
}

variable "min_task_count" {
  type    = number
  default = 3
}

variable "max_task_count" {
  type    = number
  default = 10
}




