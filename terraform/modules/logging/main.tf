// cloudwatch log


resource "aws_cloudwatch_log_group" "app" {
  name = "${var.project_name}-application-log-group"
  // 로그 보존 기간
  retention_in_days = 7
}


// log bucket
resource "aws_s3_bucket" "app_log" {
  bucket = "${var.project_name}-app-log-bucket"
}


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


// cloudwatch log에 log를 읽고 쓰기 위한 권한
resource "aws_iam_policy" "cloudwatch_log" {
  name        = "${var.project_name}-app-cloudwatch-log-policy"
  description = "log group에 로그를 남기기 위한 권한"
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
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
          "Resource" : aws_cloudwatch_log_group.app.arn
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

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda_function/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}


// cloudwatch log를 s3로 export 하기 위한 lambda
resource "aws_lambda_function" "cloudwatch_log_s3_export" {
  function_name    = "${var.project_name}-cloudwatch-log-s3-export-lambda"
  filename         = "${path.module}/lambda_function.zip"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.cloudwatch_log_export_lambda.arn
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout = 120

  runtime = "python3.11"

  environment {
    variables = {
      GROUP_NAME         = aws_cloudwatch_log_group.app.name
      DESTINATION_BUCKET = aws_s3_bucket.app_log.bucket
    }
  }


  depends_on = [
    data.archive_file.lambda
  ]

}

