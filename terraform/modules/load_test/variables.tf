variable "project_name" {
  type = string
}

variable "region" {
  type = string
}


variable "enable_load_test" {
  type = bool
}



variable "k6_key_path" {
  type    = string
  default = "keys/k6_key.pem"
}

variable "lb_dns" {
  type = string
}


variable "zone_name" {
  type = string
}