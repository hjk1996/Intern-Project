

output "public_subnet_ids" {
  value = module.vpc_moudle.public_subnet_ids
}

output "log_group_arn" {
  value = module.logging_module.log_group_arn
}