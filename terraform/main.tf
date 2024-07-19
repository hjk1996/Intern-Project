
terraform {

  backend "s3" {
    bucket = "lguplus-intern-project-tfstate"
    key    = "tfstate"
    region = "ap-northeast-2"
  }

}


provider "aws" {
  region = var.region

  default_tags {
    tags = {
      terraform   = true
      Environment = var.environment
      Application = var.project_name
    }
  }
}


module "vpc_module" {
  source = "./modules/vpc"
  region = var.region

  number_of_azs = 3

  cidr_block   = var.cidr_block
  project_name = var.project_name

  enable_vpc_interface_endpoint    = true
  interface_endpoint_service_names = var.interface_endpoint_service_names
}


module "monitoring_module" {
  source       = "./modules/monitoring"
  region       = var.region
  project_name = var.project_name


  cloudwatch_logs_retention_in_days = var.cloudwatch_logs_retention_in_days
  log_s3_lifecycle                  = var.log_s3_lifecycle


  ecs_metric_alarms = var.ecs_metric_alarms
  rds_metric_alarms = var.rds_metric_alarms
  slack_webhook_url = var.slack_webhook_url
  slack_channel     = var.slack_channel

  ecs_cluster_name = module.app_module.ecs_cluster_name
  ecs_service_name = module.app_module.ecs_service_name
  ecs_task_cpu     = var.ecs_task_cpu
  ecs_task_memory  = var.ecs_task_memory


  db_cluster_identifier = module.db_module.db_cluster_identifier
  max_connections       = var.max_connections
}

module "db_module" {
  source       = "./modules/db"
  region       = var.region
  project_name = var.project_name

  cidr_block    = var.cidr_block
  number_of_azs = var.number_of_azs
  vpc_id        = module.vpc_module.vpc_id

  db_name               = var.db_name
  db_instance_class     = var.db_instance_class
  db_private_subnet_ids = module.vpc_module.db_private_subnet_ids
  max_connections       = var.max_connections
  wait_timeout          = var.wait_timeout


  depends_on = [
    module.vpc_module
  ]
}

module "bastion_module" {
  source       = "./modules/bastion"
  region       = var.region
  project_name = var.project_name

  enable_bastion = var.enable_bastion

  vpc_id    = module.vpc_module.vpc_id
  subnet_id = module.vpc_module.public_subnet_ids[0]


  bastion_key_path = var.bastion_key_path


  depends_on = [
    module.vpc_module
  ]

}

module "app_module" {
  source       = "./modules/app"
  region       = var.region
  project_name = var.project_name

  log_group_name = module.monitoring_module.log_gorup_name
  log_group_arn  = module.monitoring_module.log_group_arn

  cidr_block        = var.cidr_block
  vpc_id            = module.vpc_module.vpc_id
  public_subnet_ids = module.vpc_module.public_subnet_ids
  app_subnet_ids    = module.vpc_module.app_subnet_ids

  db_cluster_identifier = module.db_module.db_cluster_identifier
  db_name               = module.db_module.db_name
  db_reader_endpoint    = module.db_module.db_reader_endpoint
  db_secret_arn         = module.db_module.db_secret_arn
  db_writer_endpoint    = module.db_module.db_writer_endpoint


  ecr_max_image_count = var.ecr_max_image_count

  app_port                                   = var.app_port
  ecs_task_cpu                               = var.ecs_task_cpu
  ecs_task_memory                            = var.ecs_task_memory
  predefined_target_tracking_scaling_options = var.predefined_target_tracking_scaling_options
  min_task_count                             = var.min_task_count
  max_task_count                             = var.max_task_count

  enable_dns      = var.enable_dns
  certificate_arn = module.dns_module.certificate_arn

  depends_on = [
    module.vpc_module,
    module.db_module,
  ]
}


module "dns_module" {
  source = "./modules/dns"

  enable_dns = var.enable_dns

  zone_name = var.zone_name
  lb_dns    = module.app_module.lb_dns
}

module "waf_module" {
  source       = "./modules/waf"
  project_name = var.project_name
  alb_arn      = module.app_module.alb_arn
}



module "load_test_module" {
  source       = "./modules/load_test"
  project_name = var.project_name
  region       = var.region

  enable_load_test = true

  k6_key_path = var.k6_key_path

  lb_dns    = module.app_module.lb_dns
  zone_name = var.zone_name
}





