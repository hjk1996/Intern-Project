

data "aws_region" "current" {

}
data "aws_caller_identity" "current" {

}


locals {
  metric_name             = "AppErrorCount"
  log_export_lambda_name  = "log-export-lambda"
  slack_alarm_lambda_name = "slack-alarm-lambda"
}

// ---
// cloudwatch log
resource "aws_cloudwatch_log_group" "app" {
  name = "${var.project_name}-application-log-group"
  // 로그 보존 기간
  retention_in_days = 7
}


// 장기적인 로그를 보관할 log bucket
resource "aws_s3_bucket" "app_log" {
  bucket        = "${var.project_name}-app-log-bucket"
  force_destroy = true
}

// cloudwatch logs가 s3로 로그를 전송시키기 위한 bucket policy 설정
resource "aws_s3_bucket_policy" "app_log" {
  bucket = aws_s3_bucket.app_log.bucket
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "s3:GetBucketAcl",
          "Effect" : "Allow",
          "Resource" : aws_s3_bucket.app_log.arn,
          "Principal" : { "Service" : "logs.${data.aws_region.current.name}.amazonaws.com" },
          "Condition" : {
            "ArnLike" : {
              "aws:SourceArn" : [
                "${aws_cloudwatch_log_group.app.arn}:*",
              ]
            }
          }
        },
        {
          "Action" : "s3:PutObject",
          "Effect" : "Allow",
          "Resource" : "${aws_s3_bucket.app_log.arn}/*",
          "Principal" : { "Service" : "logs.${data.aws_region.current.name}.amazonaws.com" },
          "Condition" : {
            "ArnLike" : {
              "aws:SourceArn" : [
                "${aws_cloudwatch_log_group.app.arn}:*",
              ]
            }
          }
        }
      ]
    }
  )
}

// 장기 로그 저장하는 버킷 라이프사이클 폴리시
resource "aws_s3_bucket_lifecycle_configuration" "app_log_config" {
  bucket = aws_s3_bucket.app_log.id

  rule {
    id     = "log"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

  }
}
// ---


// ---
// cloudwatch log에 자체적인 log group을 생성하고, log를 읽고 쓰기 위한 lambda 함수의 권한
resource "aws_iam_policy" "cloudwatch_log" {
  name        = "${var.project_name}-app-cloudwatch-log-policy"
  description = "log group에 로그를 남기기 위한 권한"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "logs:CreateLogGroup",
          "Resource" : "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
        },
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:GetLogEvents",
            "logs:PutLogEvents"
          ],
          "Resource" : aws_cloudwatch_log_group.app.arn
        }
      ]
    }
  )
}



// cloudwatch log를 s3로 export하기 위한 Lamba 함수의 iam role policy
resource "aws_iam_policy" "s3_log_export" {
  name        = "${var.project_name}-app-s3-log-export-policy"
  description = "s3에 log를 export하기 위한 권한"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateExportTask",
            "logs:CancelExportTask",
            "logs:DescribeExportTasks",
            "logs:DescribeLogStreams",
            "logs:DescribeLogGroups"
          ],
          "Resource" : "${aws_cloudwatch_log_group.app.arn}:*"
        },
        {
          "Action" : [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Effect" : "Allow",
          "Resource" : "arn:aws:logs:*:*:*"
        }
      ]
    }
  )
}


// lambda가 cloudwatch log를 s3로 export 하기 위해서 사용하는 iam role
resource "aws_iam_role" "cloudwatch_log_export_lambda" {
  name = "${var.project_name}-cloudwatch-log-export-lambda-role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      Statement : [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Sid    = ""
          Principal = {
            Service = "lambda.amazonaws.com"
          }
        },
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.cloudwatch_log_export_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_log_export" {
  role       = aws_iam_role.cloudwatch_log_export_lambda.name
  policy_arn = aws_iam_policy.s3_log_export.arn
}

resource "aws_iam_role_policy_attachment" "self_logging" {
  role       = aws_iam_role.cloudwatch_log_export_lambda.name
  policy_arn = aws_iam_policy.cloudwatch_log.arn
}



data "archive_file" "log_export_lambda" {
  type        = "zip"
  source_file = "${path.module}/${local.log_export_lambda_name}/lambda_function.py"
  output_path = "${path.module}/${local.log_export_lambda_name}.zip"
}


// cloudwatch log를 s3로 export 하기 위한 lambda
resource "aws_lambda_function" "cloudwatch_log_s3_export" {
  function_name    = "${var.project_name}-${local.log_export_lambda_name}"
  filename         = "${path.module}/${local.log_export_lambda_name}.zip"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.cloudwatch_log_export_lambda.arn
  source_code_hash = data.archive_file.log_export_lambda.output_base64sha256
  timeout          = 120

  runtime = "python3.11"

  environment {
    variables = {
      GROUP_NAME         = aws_cloudwatch_log_group.app.name
      DESTINATION_BUCKET = aws_s3_bucket.app_log.bucket
    }
  }


  depends_on = [
    data.archive_file.log_export_lambda
  ]
}


# scheduler가 lambda를 트리거 하기 위한 iam role
resource "aws_iam_role" "lambda_trigger_scheduler" {
  name = "${var.project_name}-lambda-trigger-scheduler-role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      Statement : [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Sid    = ""
          Principal = {
            Service = "scheduler.amazonaws.com"
          }
        },
      ]
    }
  )
}

resource "aws_iam_policy" "trigger_lambda" {
  name        = "${var.project_name}-scheduler-trigger-lambda-policy"
  description = "eventbridge scheduler가 lambda를 트리거하기 위한 정책"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "lambda:InvokeFunction"
          ],
          "Resource" : aws_lambda_function.cloudwatch_log_s3_export.arn
        }
      ]
    }
  )

}


resource "aws_iam_role_policy_attachment" "trigger_lambda" {
  role       = aws_iam_role.lambda_trigger_scheduler.name
  policy_arn = aws_iam_policy.trigger_lambda.arn
}


# scheduler가 lambda를 trigger하기 위한 permission
resource "aws_lambda_permission" "allow_scheduler" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cloudwatch_log_s3_export.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.cloudwatch_log_s3_export.arn
}


# 매일 새벽 1시마다 lambda 함수를 트리거하는 스케쥴
# 현재는 테스트를 위해 매 5분마다 트리거하도록 설정
resource "aws_scheduler_schedule" "cloudwatch_log_s3_export" {
  name = "${var.project_name}-cloudwatch-log-s3-export-schedule"

  flexible_time_window {
    mode = "OFF"
  }

  # 매일 새벽 1시에 trigger
  # 분 시 일 월 요일 년
  # ?는 특정 요일이 없다는 뜻임
  # schedule_expression = "rate(5 minutes)"
  schedule_expression = "cron(* 1 * * ? *)"

  target {
    # event bridge가 스케쥴마다 트리거할 대상
    arn = aws_lambda_function.cloudwatch_log_s3_export.arn
    # event bridge가 사용할 iam role arn
    role_arn = aws_iam_role.lambda_trigger_scheduler.arn
  }
}
// ---


// ---
// 애플리케이션에 에러에 대한 메트릭 필터
resource "aws_cloudwatch_log_metric_filter" "app_error" {
  name           = "${var.project_name}-app-error-log-filter"
  pattern        = "{ $.level = \"error\" }"
  log_group_name = aws_cloudwatch_log_group.app.name

  metric_transformation {
    name      = local.metric_name
    namespace = var.project_name
    value     = "1"
  }


}

// 애플리케이션 에러 로그 알람
resource "aws_cloudwatch_metric_alarm" "app_error_alarm" {
  alarm_name          = "${var.project_name}-app-error-alarm"
  alarm_description   = "application 에러 로그에 대한 알람"
  metric_name         = local.metric_name
  threshold           = "0"
  statistic           = "Sum"
  comparison_operator = "GreaterThanThreshold"
  // 알람을 트리거링 하기 위한 데이터포인트의 수
  datapoints_to_alarm = "1"
  evaluation_periods  = "1"
  // 메트릭을 평가하기 위한 시간 윈도우 사이즈 (초단위)
  period          = "60"
  namespace       = var.project_name
  actions_enabled = true
  alarm_actions   = [aws_sns_topic.app_error.arn]

}

// 에러 로그가 전송되는 SNS
resource "aws_sns_topic" "app_error" {
  name = "${var.project_name}-app-error-topic"
}

resource "aws_sns_topic_subscription" "slack_lambda" {
  topic_arn = aws_sns_topic.app_error.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_alarm.arn
}


// 알람 발생하면 slack으로 알람 보내는 람다
data "archive_file" "slack_alarm_lambda" {
  type        = "zip"
  source_file = "${path.module}/${local.slack_alarm_lambda_name}/lambda_function.py"
  output_path = "${path.module}/${local.slack_alarm_lambda_name}.zip"
}


// cloudwatch log를 s3로 export 하기 위한 lambda
resource "aws_lambda_function" "slack_alarm" {
  function_name    = "${var.project_name}-${local.slack_alarm_lambda_name}"
  filename         = "${path.module}/${local.slack_alarm_lambda_name}.zip"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.cloudwatch_log_export_lambda.arn
  source_code_hash = data.archive_file.slack_alarm_lambda.output_base64sha256
  timeout          = 120

  runtime = "python3.11"

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
      SLACK_CHANNEL     = var.slack_channel
    }
  }


  depends_on = [
    data.archive_file.slack_alarm_lambda
  ]
}

# scheduler가 lambda를 trigger하기 위한 permission
resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_alarm.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.app_error.arn
}


// slack channel에 alarm을 보내기 위한 lambda의 iam role
resource "aws_iam_role" "slack_alarm_role" {
  name = "${var.project_name}-slack-alarm-role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      Statement : [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Sid    = ""
          Principal = {
            Service = "lambda.amazonaws.com"
          }
        },
      ]
    }
  )
}

resource "aws_iam_policy" "sns_trigger_lambda" {
  name        = "${var.project_name}-slack-alarm-lambda-policy"
  description = "sns가 lambda를 트리거하기 위한 정책"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "lambda:InvokeFunction"
          ],
          "Resource" : aws_sns_topic.app_error.arn
        }
      ]
    }
  )

}


resource "aws_iam_role_policy_attachment" "sns_trigger_lambda" {
  role       = aws_iam_role.slack_alarm_role.name
  policy_arn = aws_iam_policy.sns_trigger_lambda.arn
}



// ecs 서비스의 평균적인 cpu 사용량이 80를 초과하면 전송되는 알람
resource "aws_cloudwatch_metric_alarm" "service_cpu_alarm" {
  alarm_name          = "${var.project_name}-ecs-service-average-CPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2" # 연속된 두 평가 기간 동안 조건이 충족되어야 합니다.
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "30" # 30초마다 메트릭을 수집합니다.
  statistic           = "Average"
  threshold           = "0.8" # CPU 사용량이 80%를 초과할 때 알람
  alarm_description   = "This alarm monitors the average CPU utilization of the ECS service."
  actions_enabled     = true

  dimensions = {
    ClusterName = var.ecs_cluster_name  # ECS 클러스터 이름
    ServiceName = var.ecs_service_name  # ECS 서비스 이름
  }

  alarm_actions = [
    aws_sns_topic.app_error.arn  # 알람이 발생했을 때 알림을 받을 SNS 주제 ARN
  ]

}

resource "aws_cloudwatch_metric_alarm" "service_memory_alarm" {
  alarm_name          = "${var.project_name}-ecs-service-average-MemoryUtilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2" # 연속된 두 평가 기간 동안 조건이 충족되어야 합니다.
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "30" # 30초마다 메트릭을 수집합니다.
  statistic           = "Average"
  threshold           = "80" # 메모리 사용량이 80%를 초과할 때 알람
  alarm_description   = "This alarm monitors the average memory utilization of the ECS service."
  actions_enabled     = true

  dimensions = {
    ClusterName = var.ecs_cluster_name  # ECS 클러스터 이름
    ServiceName = var.ecs_service_name  # ECS 서비스 이름
  }

  alarm_actions = [
    aws_sns_topic.app_error.arn  # 알람이 발생했을 때 알림을 받을 SNS 주제 ARN
  ]

}






// ecs 서비스의 평균적인 메모리 사용량이 ~~를 초과하면 전송되는 알람








