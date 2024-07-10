data "aws_rds_cluster" "main" {
  cluster_identifier = var.db_cluster_identifier
}

resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

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

// ecs cluster
resource "aws_ecs_cluster" "main" {

  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

// task role
resource "aws_iam_role" "task_role" {
  name = "${var.project_name}-app-task-role"
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      Statement : [
        {
          Action = "sts:AssumeRole"
          Effect = "Allow"
          Sid    = ""
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
        },
      ]
    }
  )
}




// 앱에 대한 task definition
resource "aws_ecs_task_definition" "app" {
  family = "${var.project_name}-app"

  task_role_arn      = aws_iam_role.task_role.arn


  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:prod"
      cpu       = 10
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
        }
      ]
    environment = [
        {
            name = "DB_SECRET_NAME"
            value = "temp"
        },
        {
            name = "READER_ENDPOINT"
            value = data.aws_rds_cluster.main.reader_endpoint
        },
        {
            name = "WRITER_ENDPOINT"
            value = data.aws_rds_cluster.main.endpoint
        },
        {
            name = "DB_NAME"
            value = data.aws_rds_cluster.main.database_name
        },



    ]
    }
  ])
}


