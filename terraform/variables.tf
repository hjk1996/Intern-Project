
variable "project_name" {
  type        = string
  default     = "intern-project"
  description = "프로젝트 이름"
}

variable "region" {
  type        = string
  default     = "ap-northeast-2"
  description = "서비스를 배포할 region"
}



// ---------------------------
// 네트워크 관련 변수
variable "cidr_block" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR Block"
}
// TODO
variable "enable_vpc_interface_endpoint" {
  type        = bool
  default     = true
  description = "AWS Service에 대한 interface endpoint를 활성화 시킬 것인지에 대한 여부"
}
variable "interface_endpoint_service_names" {
  type        = list(string)
  description = "Interface Endpoint를 생성시킬 AWS 서비스 이름 목록"
}

variable "number_of_azs" {
  type        = number
  description = "가용 영역의 수. 가용 영역의 수에 따라 NGW와 데이터베이스 인스턴스의 수가 결정됩니다."
  validation {

    condition     = var.number_of_azs > 0 && var.number_of_azs <= 3
    error_message = "가용 영역의 수는 1개 이상 3개 이하여야 합니다."
  }
}




// ---------------------------
// bastion 관련 변수
variable "enable_bastion" {
  type        = bool
  description = "public subent에 bastion host를 생성할 지 여부를 결정합니다."
}
variable "bastion_key_path" {
  type        = string
  description = "bastion 인스턴스에 접속하기 위한 private key가 저장되는 로컬 경로"
}


// ---------------------------
// 모니터링 관련 변수

variable "cloudwatch_logs_retention_in_days" {
  type        = number
  description = "cloudwatch logs에 로그가 저장되는 기간"
}


variable "log_s3_lifecycle" {
  type = object({
    standard_ia = number
    glacier     = number
  })
  description = "며칠 뒤에 s3 오브젝트의 클래스가 해당 클래스로 전환되는지 결정"
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
  description = "ECS Service에서 모니터링하고 알람을 받을 지표에 대한 설정"

  default = [{
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods  = "2"
    statistic           = "Average"
    metric_name         = "CPUUtilization"
    period              = "30"
    threshold           = "70"
    enable_ok_action    = false
  }]
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
  description = "RDS에서 모니터링하고 알람을 받을 지표에 대한 설정"

  default = [{
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods  = "2"
    statistic           = "Maximum"
    metric_name         = "CPUUtilization"
    period              = "30"
    threshold           = "70"
    enable_ok_action    = false
  }]




}







variable "slack_channel" {
  type        = string
  description = "알람 메시지를 보낼 slack channel 이름"
}

variable "slack_webhook_url" {
  type        = string
  description = "slack webhook 주소"

}


// ---------------------------
// DB 관련 변수
variable "db_instance_class" {
  type        = string
  default     = "db.t3.micro"
  description = "DB 인스턴스 타입"
}

variable "db_name" {
  type        = string
  default     = "app"
  description = "DB 이름"
}


variable "max_connections" {
  type        = number
  description = "DB에서 허용하는 최대 커넥션 수"
}

variable "wait_timeout" {
  type        = number
  description = "DB에서 활동하지 않는 커넥션을 끊을 때까지 대기하는 시간"
}



// ---------------------------
// 애플리케이션 관련 변수
variable "app_port" {
  type        = number
  default     = 8080
  description = "애플리케이션이 통신에 사용할 포트 번호"
}

variable "min_task_count" {
  type        = number
  default     = 3
  description = "ECS Task의 최소 실행 갯수"
}

variable "max_task_count" {
  type        = number
  default     = 10
  description = "ECS Task의 최대 실행 갯수"
}


variable "ecr_max_image_count" {
  type        = number
  description = "ECR에 저장할 최대 이미지 갯수"
}


variable "predefined_target_tracking_scaling_options" {
  type = list(object({
    predefined_metric_type = string
    target_value           = number
    scale_in_cooldown      = number
    scale_out_cooldown     = number
  }))

  default = [{
    predefined_metric_type = "ECSServiceAverageCPUUtilization"
    target_value           = 50
    scale_in_cooldown      = 300
    scale_out_cooldown     = 10
  }]

  description = "target tracking 오토 스케일링 정책"

}


variable "ecs_task_cpu" {
  type        = number
  description = "ECS Task에 부여될 CPU 용량 (256 = 0.25 vCPU)"
}

variable "ecs_task_memory" {
  type        = number
  description = "ECS Task에 부여될 Memory 용량 (MB)"
}

variable "additional_env_vars" {
  type = list(object(
    {
      key   = string
      value = string
    }
  ))
  default     = null
  description = "container에 부여할 추가적인 환경 변수들"
}



# variable "ecs_alarms" {
#   type = list(object({
#     metric_name = string
#     period = number
#     evaluation_periods = number
#     threshold = number
#     statistic = string
#     comparison_operator = string 
#     alarm_action = bool
#     ok_action = bool
#   }))
# }

# variable "rds_alarms" {
#   type = list(object({
#     metric_name = string
#     period = number
#     evaluation_periods = number
#     threshold = number
#     statistic = string
#     comparison_operator = string 
#     alarm_action = bool
#     ok_action = bool
#   }))
# }



// ---------------------------
// DNS 관련 변수
variable "enable_dns" {
  type        = bool
  description = "ALB에 도메인 네임을 부여할 지에 대한 여부를 결정합니다."
}


variable "zone_name" {
  type        = string
  description = "사용할 도메인 이름"
}

variable "lb_cname" {
  type        = string
  description = "ALB와 연결할 서브 도메인 이름"
}



// ---------------------------
// 부하 테스트 관련 변수
variable "enable_load_test" {
  type        = bool
  description = "load test를 위한 인스턴스를 생성할 것인지에 대한 여부"
}
variable "k6_key_path" {
  type        = string
  description = "부하 테스트용 인스턴스에 접근하기 위한 private key가 저장될 로컬 경로"
}


