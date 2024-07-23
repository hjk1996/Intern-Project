


locals {

  az_alphabets = ["a", "c", "d"]

  azs = [for n in range(var.number_of_azs) : "${var.region}${local.az_alphabets[n]}"]


  new_deployment_lambda_name = "new_deployment_lambda"

}

data "aws_caller_identity" "current" {

}


// DB 서브넷 그룹
resource "aws_db_subnet_group" "main" {

  name       = "${var.project_name}-subnet-group"
  subnet_ids = var.db_private_subnet_ids
}

// DB 보안 그룹
resource "aws_security_group" "db" {
  name   = "${var.project_name}-db-sg"
  vpc_id = var.vpc_id

  ingress {
    protocol    = "TCP"
    from_port   = 3306
    to_port     = 3306
    cidr_blocks = [var.cidr_block]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }


}

resource "aws_db_parameter_group" "main" {
  name   = "${var.project_name}-aurora-mysql-pg"
  family = "aurora-mysql5.7"


  parameter {
    name  = "max_execution_time"
    value = 120000
  }

  parameter {
    name  = "max_connections"
    value = var.max_connections
  }

  parameter {
    name  = "wait_timeout"
    value = var.wait_timeout
  }

}



// DB Cluster
resource "aws_rds_cluster" "main" {
  cluster_identifier   = "${var.project_name}-db-cluster"
  availability_zones   = local.azs
  engine               = "aurora-mysql"
  engine_version       = "5.7.mysql_aurora.2.11.5"
  database_name        = var.db_name
  storage_encrypted    = true
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [
    aws_security_group.db.id
  ]

  skip_final_snapshot         = true
  apply_immediately           = true
  manage_master_user_password = true
  master_username             = "master"
}

// DB Instance
resource "aws_rds_cluster_instance" "main" {
  count                   = var.number_of_azs
  identifier              = "${var.project_name}-db-${count.index}"
  cluster_identifier      = aws_rds_cluster.main.id
  instance_class          = var.db_instance_class
  db_parameter_group_name = aws_db_parameter_group.main.name
  apply_immediately       = true
  engine                  = aws_rds_cluster.main.engine
  engine_version          = aws_rds_cluster.main.engine_version
}

resource "aws_iam_role" "new_deployment_lambda" {
  name        = "${var.project_name}-new-deployment-on-secret-rotation-lambda"
  # description = "Secrets Manager에서 암호가 교체되면 새로운 암호를 반영할 수 있도록 ECS Service를 다시 배포함"
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


resource "aws_iam_policy" "new_deployment_lambda" {
  name = "${var.project_name}-new-deployment-lambda"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "ecs:UpdateService",
            "ecs:DescribeServices"
          ],
          "Resource" : "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/${var.ecs_cluster_name}/${var.ecs_service_name}"
        },
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.new_deployment_on_rotation.function_name}:*"
            ]
        }
      ]
    }
  )
}


resource "aws_iam_role_policy_attachment" "new_deployment_lambda" {

  role       = aws_iam_role.new_deployment_lambda.name
  policy_arn = aws_iam_policy.new_deployment_lambda.arn
}

data "archive_file" "new_deployment_lambda" {
  type        = "zip"
  source_file = "${path.module}/${local.new_deployment_lambda_name}/lambda_function.py"
  output_path = "${path.module}/${local.new_deployment_lambda_name}.zip"
}



resource "aws_lambda_function" "new_deployment_on_rotation" {
  function_name    = "${var.project_name}-new-deployment-on-secret-rotation-lambda"
  filename         = "${path.module}/${local.new_deployment_lambda_name}.zip"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.new_deployment_lambda.arn
  source_code_hash = data.archive_file.new_deployment_lambda.output_base64sha256
  timeout          = 120

  runtime = "python3.11"

  environment {
    variables = {
      "ECS_CLUSTER_NAME" = var.ecs_cluster_name
      "ECS_SERVICE_NAME" = var.ecs_service_name
    }
  }

  depends_on = [
    data.archive_file.new_deployment_lambda
  ]

}


resource "aws_cloudwatch_event_rule" "secret_update_rule" {
  name        = "secret-update-rule"
  description = "Triggers when a secret is updated in Secrets Manager"
  event_pattern = jsonencode({
    "source": [
      "aws.secretsmanager"
    ],
    "detail-type": [
      "AWS API Call via CloudTrail"
    ],
    "detail": {
      "eventName": [
        "RotateSecret",
        "UpdateSecret",
        "CreateSecret"

      ],
      "requestParameters": {
        "secretId": [
          aws_rds_cluster.main.master_user_secret[0].secret_arn
        ]
      }
    }
  })
}


resource "aws_cloudwatch_event_target" "secret_update_event" {
  rule = aws_cloudwatch_event_rule.secret_update_rule.name
  target_id = "lambda"
  arn = aws_lambda_function.new_deployment_on_rotation.arn
}

resource "aws_lambda_permission" "event_rule" {
    statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.new_deployment_on_rotation.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.secret_update_rule.arn
  
}



