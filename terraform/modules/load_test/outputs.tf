


output "k6_dns" {
  value = var.enable_load_test ? aws_instance.k6[0].public_dns : null
}