output "ecr_address" {
  value = aws_ecr_repository.app.repository_url
}

output "lb_dns" {
  value = aws_lb.app.dns_name
}

output "alb_arn" {
  value = aws_lb.app.arn
}

output "ecs_target_group_arn" {
  value = aws_lb_target_group.ecs_app.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app.name
}

