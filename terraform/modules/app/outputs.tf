output "ecr_address" {
  value = aws_ecr_repository.app.repository_url
}

output "lb_dns" {
  value = aws_lb.app.dns_name
}
