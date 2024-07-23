variable "enable_dns" {
  type = bool
}

variable "zone_name" {
  type = string
}

variable "lb_dns" {
  type = string
}

variable "alb_arn" {
  type = string
}

variable "ecs_target_group_arn" {
  type = string
}