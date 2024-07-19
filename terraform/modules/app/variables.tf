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

variable "ecr_max_image_count" {
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

variable "predefined_target_tracking_scaling_options" {
  type = list(object({
    predefined_metric_type = string
    target_value           = number
    scale_in_cooldown      = number
    scale_out_cooldown     = number
  }))
}


variable "ecs_task_cpu" {
  type = number
}


variable "ecs_task_memory" {
  type = number
}



variable "additional_env_vars" {
  type = list(object(
    {
      key   = string
      value = string
    }
  ))

  default = null

}




variable "certificate_arn" {
  type = string
}


variable "enable_dns" {
  type = bool
}





