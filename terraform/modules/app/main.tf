data "aws_region" "current" {

}

locals {
  container_name = "${var.project_name}-app"
  utc_time_gap   = 9
}


// ECR 리포지토리
resource "aws_ecr_repository" "app" {
  name                 = local.container_name
  image_tag_mutability = "IMMUTABLE"
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
          "description" : "태그가 붙은 이미지는 총 30개만 저장",
          "selection" : {
            "tagStatus" : "tagged",
            "tagPatternList" : ["*"],
            "countType" : "imageCountMoreThan",
            "countNumber" : var.ecr_max_image_count
          },
          "action" : {
            "type" : "expire"
          }
        },

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

// ecs task role
resource "aws_iam_role" "ecs_task" {
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
          "Resource" : var.db_secret_arn
        }

      ]

    }
  )

}

resource "aws_iam_role_policy_attachment" "secret_manager_access" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.secret_manager_access.arn
}

// ecs execution role
resource "aws_iam_role" "ecs_execution" {
  name = "${local.container_name}-execution-role-2"
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


resource "aws_iam_policy" "cloudwatch_logs_access" {
  name = "${local.container_name}-cloudwatch-logs-access-2"
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
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "log" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = aws_iam_policy.cloudwatch_logs_access.arn

}


// 앱에 대한 task definition
resource "aws_ecs_task_definition" "app" {
  family = local.container_name

  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"

  cpu    = var.ecs_task_cpu
  memory = var.ecs_task_memory

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = "${aws_ecr_repository.app.repository_url}:48"
      cpu       = var.ecs_task_cpu
      memory    = var.ecs_task_memory
      essential = true
      portMappings = [
        {
          containerPort = var.app_port
          hostPort      = var.app_port
        }
      ]
      environment = concat(
        [
          {
            name  = "DB_SECRET_NAME"
            value = var.db_secret_arn
          },
          {
            name  = "READER_ENDPOINT"
            value = var.db_reader_endpoint
          },
          {
            name  = "WRITER_ENDPOINT"
            value = var.db_writer_endpoint
          },
          {
            name  = "DB_NAME"
            value = var.db_name
          },
          {
            name  = "APP_PORT"
            value = "${tostring(var.app_port)}"
          }
        ],
        var.additional_env_vars == null ? [] : var.additional_env_vars
      )

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.region
          awslogs-stream-prefix = "ecs"
        }
      }


    }
  ])

  lifecycle {
    ignore_changes = [
      container_definitions
    ]
  }
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
  desired_count   = var.work_time_min_task_count
  launch_type     = "FARGATE"


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

  lifecycle {
    ignore_changes = [
      desired_count
    ]

  }

  depends_on = [ 
    aws_lb.app
   ]
}

// alb security group
resource "aws_security_group" "lb" {
  name   = "${local.container_name}-lb-sg"
  vpc_id = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

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
  name            = "${local.container_name}-alb"
  security_groups = [aws_security_group.lb.id]
  internal        = false

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







// ECS Task scaling 정책 (CPU)
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_task_count
  min_capacity       = var.work_time_min_task_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}


resource "aws_appautoscaling_policy" "target_tracking" {
  count              = length(var.predefined_target_tracking_scaling_options)
  name               = "${var.project_name}-${var.predefined_target_tracking_scaling_options[count.index].predefined_metric_type}-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.app.name}"
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.predefined_target_tracking_scaling_options[count.index].target_value
    predefined_metric_specification {
      predefined_metric_type = var.predefined_target_tracking_scaling_options[count.index].predefined_metric_type
    }
    scale_in_cooldown  = var.predefined_target_tracking_scaling_options[count.index].scale_in_cooldown
    scale_out_cooldown = var.predefined_target_tracking_scaling_options[count.index].scale_out_cooldown
  }
}

resource "aws_appautoscaling_scheduled_action" "work_time" {
  name               = "ecs"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  schedule           = "cron(* 9 * * ? *)"

  scalable_target_action {
    min_capacity = var.work_time_min_task_count
    max_capacity = var.max_task_count
  }
}



resource "aws_appautoscaling_scheduled_action" "not_work_time" {
  name               = "ecs"
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  schedule           = "cron(* 18 * * ? *)"

  scalable_target_action {
    min_capacity = var.not_work_time_min_task_count
    max_capacity = var.max_task_count
  }

  depends_on = [aws_appautoscaling_scheduled_action.work_time]
}

