output "cloudwatch_log_policy_arn" {
  value = aws_iam_policy.cloudwatch_log.arn
}

output "s3_log_export_policy_arn" {
  value = aws_iam_policy.s3_log_export.arn
}

output "log_group_arn" {
  value = aws_cloudwatch_log_group.app.arn
}

output "log_gorup_name" {
  value = aws_cloudwatch_log_group.app.name
}



