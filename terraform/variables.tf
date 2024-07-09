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
  type = string
  default = "db.t3.micro"
}


variable "ssh_key_path" {
  type = string
  
}