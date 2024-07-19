variable "region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "slack_webhook_url" {
  type = string
}

variable "slack_channel" {
  type = string
}

variable "ecs_cluster_name" {
  type = string
}

variable "ecs_service_name" {
  type = string
}

variable "ecs_task_memory" {
  type = number
}

variable "ecs_task_cpu" {
  type = number
}


variable "db_cluster_identifier" {
  type = string
}

variable "max_connections" {
  type = number
}


variable "ecs_metric_alarms" {
  type = list(object({
    comparison_operator = string
    evaluation_periods  = string
    statistic           = string
    metric_name         = string
    period              = string
    threshold           = string
    enable_ok_action    = bool
  }))
}

variable "rds_metric_alarms" {
  type = list(object({
    comparison_operator = string
    evaluation_periods  = string
    statistic           = string
    metric_name         = string
    period              = string
    threshold           = string
    enable_ok_action    = bool
  }))
}





variable "cloudwatch_logs_retention_in_days" {
  type = number

}


variable "log_s3_lifecycle" {
  type = object({
    standard_ia = number
    glacier     = number
  })
}