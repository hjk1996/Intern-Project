locals {
  ecs_scale_lambda_name = "ecs_scale_lambda"
  utc_time_gap          = 9
}

data "aws_caller_identity" "current" {

}


resource "aws_iam_role" "ecs_scale_lambda" {
  name = "${var.project_name}-ecs-scale-lambda-role"
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

resource "aws_iam_policy" "ecs_scale" {
  name = "${var.project_name}-ecs-scale-policy"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "ecs:UpdateService",
          "ecs:DescribeService",
          "ecs:DescribeClusters",
          "ecs:UpdateService",
        ],
        "Resource" : "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"
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
  })

}



resource "aws_iam_role_policy_attachment" "ecs_scale" {
  role       = aws_iam_role.ecs_scale_lambda.name
  policy_arn = aws_iam_policy.ecs_scale.arn

}



data "archive_file" "ecs_scale_lambda" {
  type        = "zip"
  source_file = "${path.module}/${local.ecs_scale_lambda_name}/lambda_function.py"
  output_path = "${path.module}/${local.ecs_scale_lambda_name}.zip"
}


// cloudwatch log를 s3로 export 하기 위한 lambda
resource "aws_lambda_function" "ecs_scale_out" {
  function_name    = "${var.project_name}-${local.ecs_scale_lambda_name}"
  filename         = "${path.module}/${local.ecs_scale_lambda_name}.zip"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.ecs_scale_lambda.arn
  source_code_hash = data.archive_file.ecs_scale_lambda.output_base64sha256
  timeout          = 120

  runtime = "python3.11"

  environment {
    variables = {
      DESIRED_COUNT = 6
    }
  }

  depends_on = [
    data.archive_file.ecs_scale_lambda
  ]
}


# scheduler가 lambda를 트리거 하기 위한 iam role
resource "aws_iam_role" "ecs_scale_scheduler" {
  name = "${var.project_name}-ecs-scale-scheduler-role"
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
  name        = "${var.project_name}-ecs-scale-scheduler-trigger-lambda-policy"
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
          "Resource" : aws_lambda_function.ecs_scale_out.arn
        }
      ]
    }
  )

}


resource "aws_iam_role_policy_attachment" "trigger_ecs_scale_lambda" {
  role       = aws_iam_role.ecs_scale_scheduler.name
  policy_arn = aws_iam_policy.trigger_lambda.arn
}


# scheduler가 lambda를 trigger하기 위한 permission
resource "aws_lambda_permission" "allow_scheduler" {
  statement_id  = "AllowExecutionFromEventBridgeScheduler"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_scale_out.function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_scheduler_schedule.ecs_scale_out.arn
}


# 매일 새벽 1시마다 lambda 함수를 트리거하는 스케쥴
resource "aws_scheduler_schedule" "ecs_scale_out" {
  name = "${var.project_name}-ecs-scale-out-schedule"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = "cron(* ${19 - local.utc_time_gap} * * ? *)"

  target {
    # event bridge가 스케쥴마다 트리거할 대상
    arn = aws_lambda_function.ecs_scale_out.arn
    # event bridge가 사용할 iam role arn
    role_arn = aws_iam_role.ecs_scale_lambda.arn
  }
}