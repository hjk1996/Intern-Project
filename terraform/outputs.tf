output "bastion_dns_name" {
  value = module.bastion_module.bastion_dns_name
}

output "db_writer_endpoint" {
  value = module.db_module.db_writer_endpoint
}

output "db_reader_endpoint" {
  value = module.db_module.db_reader_endpoint
}

output "ecr_address" {
  value = module.app_module.ecr_address
}


output "lb_dns" {
  value = module.app_module.lb_dns
}


output "k6_dns" {
  value = module.load_test_module.k6_dns
}

output "db_parameter_group_name" {
  value = module.db_module.db_parameter_group_name
}