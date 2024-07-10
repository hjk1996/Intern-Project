output "ecr_address" {
  value = aws_ecr_repository.app.repository_url
}
