output "ecr_address" {
  value = aws_ecr_repository.app.repository_url
}

output "lb_dns" {
  value = aws_lb.app.dns_name
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

output "cpu_alarm_arn" {
  value = aws_appautoscaling_policy.cpu_scaling_policy.alarm_arns[0]
}