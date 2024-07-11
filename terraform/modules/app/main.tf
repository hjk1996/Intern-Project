data "aws_rds_cluster" "main" {
  cluster_identifier = var.db_cluster_identifier
}

data "aws_region" "current" {

}

locals {
  container_name = "${var.project_name}-app"
}


// ECR 리포지토리
resource "aws_ecr_repository" "app" {
  name                 = local.container_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

// ECR 리포지토리 라이프사이클 정책
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode(

    {
      "rules" : [
        {
          "rulePriority" : 10,
          "description" : "prod 태그가 붙은 이미지는 1개만 저장",
          "selection" : {
            "tagStatus" : "tagged",
            "tagPrefixList" : ["prod"],
            "countType" : "imageCountMoreThan",
            "countNumber" : 1
          },
          "action" : {
            "type" : "expire"
          }
        },
        {
          "rulePriority" : 20,
          "description" : "태그가 붙은 이미지는 총 30개만 저장",
          "selection" : {
            "tagStatus" : "tagged",
            "tagPatternList" : ["*"],
            "countType" : "imageCountMoreThan",
            "countNumber" : 30
          },
          "action" : {
            "type" : "expire"
          }
        },
        {
          "rulePriority" : 980,
          "description" : "태그없는 이미지는 1개만 유지함",
          "selection" : {
            "tagStatus" : "untagged",
            "countType" : "imageCountMoreThan",
            "countNumber" : 1
          },
          "action" : {
            "type" : "expire"
          }
        }
      ]
    }
  )

}

resource "aws_ecs_cluster" "main" {

  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

// task role
resource "aws_iam_role" "task_role" {
  name = "${local.container_name}-task-role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow"
          "Action" : "sts:AssumeRole"
          "Sid" : ""
          "Principal" : {
            "Service" : "ecs-tasks.amazonaws.com"
          }
        },
      ]
    }
  )
}

resource "aws_iam_policy" "secret_manager_access" {
  name = "${local.container_name}-secret-manager-access"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow"
          "Action" : [
            "secretsmanager:GetSecretValue"
          ]
          "Resource" : data.aws_rds_cluster.main.master_user_secret[0].secret_arn
        }

      ]

    }
  )

}

resource "aws_iam_role_policy_attachment" "secret_manager_access" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.secret_manager_access.arn
}

// execution role
resource "aws_iam_role" "execution_role" {
  name = "${local.container_name}-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "log" {
  name = "${local.container_name}-cloudwatch-logs-access"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow"
          "Action" : [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          "Resource" : "${var.log_group_arn}:*"
        }

      ]

    }
  )

}


resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "log" {
  role       = aws_iam_role.execution_role.name
  policy_arn = aws_iam_policy.log.arn

}


// 앱에 대한 task definition
resource "aws_ecs_task_definition" "app" {
  family = local.container_name

  execution_role_arn = aws_iam_role.execution_role.arn
  task_role_arn      = aws_iam_role.task_role.arn

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = 256
  memory = 512

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = "${aws_ecr_repository.app.repository_url}:prod"
      cpu       = 10
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
        }
      ]
      environment = [
        {
          name  = "DB_SECRET_NAME"
          value = data.aws_rds_cluster.main.master_user_secret[0].secret_arn
        },
        {
          name  = "READER_ENDPOINT"
          value = data.aws_rds_cluster.main.reader_endpoint
        },
        {
          name  = "WRITER_ENDPOINT"
          value = data.aws_rds_cluster.main.endpoint
        },
        {
          name  = "DB_NAME"
          value = data.aws_rds_cluster.main.database_name
        },
        {
          name  = "APP_PORT"
          value = "${tostring(var.app_port)}"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

// task의 security group

resource "aws_security_group" "ecs_task" {

  name   = "${local.container_name}-sg"
  vpc_id = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = var.app_port
    to_port     = var.app_port
    cidr_blocks = [var.cidr_block]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]

  }

}




resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.arn
  task_definition = aws_ecs_task_definition.app.arn
  launch_type     = "FARGATE"
  desired_count   = 3


  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = true
  }


  load_balancer {
    container_port   = var.app_port
    container_name   = local.container_name
    target_group_arn = aws_lb_target_group.ecs_app.arn
  }


}

// alb security group
resource "aws_security_group" "lb" {

  name   = "${local.container_name}-lb-sg"
  vpc_id = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]

  }

}

resource "aws_lb" "app" {
  name               = "${local.container_name}-alb"
  security_groups    = [aws_security_group.lb.id]
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids


}

resource "aws_lb_target_group" "ecs_app" {
  name        = "${local.container_name}-alb-tg"
  port        = var.app_port
  vpc_id      = var.vpc_id
  protocol    = "HTTP"
  target_type = "ip"



  health_check {
    enabled           = true
    protocol          = "HTTP"
    matcher           = 200
    healthy_threshold = 3
    interval          = 30
  }
}


resource "aws_lb_listener" "ecs_app" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_app.arn
  }

}

