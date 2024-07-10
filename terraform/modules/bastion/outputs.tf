output "bastion_dns_name" {
  value = aws_instance.bastion.public_dns

}

output "ami_id" {
  value = data.aws_ami.ubuntu.id
}