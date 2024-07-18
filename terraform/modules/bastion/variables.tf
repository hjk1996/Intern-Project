variable "enable_bastion" {
  type = bool
}

variable "region" {
  type = string
}
variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "bastion_key_path" {
  type = string

}