output "log_group_arn" {
  value = module.logging_module.log_group_arn
}

output "bastion_dns_name" {
  value = module.bastion_module.bastion_dns_name
}

output "db_endpoint" {
  value = module.db_module.db_endpoint
}

output "db_reader_endpoint" {
  value = module.db_module.db_reader_endpoint
}

output "ecr_address" {
  value = module.app_module.ecr_address
}

output "secret_id" {
  value = module.db_module.secret_id
}

output "ami_id" {
  value = module.bastion_module.ami_id
}