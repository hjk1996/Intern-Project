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


variable "ecs_metric_names" {
  
}

