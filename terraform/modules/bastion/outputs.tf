output "bastion_dns_name" {
  value = var.enable_bastion ? aws_instance.bastion[0].public_dns : null
}
