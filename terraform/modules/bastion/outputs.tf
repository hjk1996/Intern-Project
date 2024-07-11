output "bastion_dns_name" {
  value = aws_instance.bastion.public_dns

}
