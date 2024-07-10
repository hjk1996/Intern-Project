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
      Environment = "prod"
      Application = "intern-project"
    }
  }
}


module "vpc_module" {
  source       = "./modules/vpc"
  cidr_block   = var.cidr_block
  project_name = var.project_name
}



module "logging_module" {
  source       = "./modules/logging"
  project_name = var.project_name
}

module "db_module" {
  source                = "./modules/db"
  region                = var.region
  project_name          = var.project_name
  vpc_id                = module.vpc_module.vpc_id
  db_instance_class     = var.db_instance_class
  db_private_subnet_ids = module.vpc_module.db_private_subnet_ids
  cidr_block            = var.cidr_block
  db_password           = var.db_password
  db_name               = var.db_name

  depends_on = [
    module.vpc_module
  ]
}

module "bastion_module" {
  source       = "./modules/bastion"
  project_name = var.project_name
  vpc_id       = module.vpc_module.vpc_id
  subnet_id    = module.vpc_module.public_subnet_ids[0]
  ssh_key_path = var.ssh_key_path


  depends_on = [ 
    module.vpc_module
   ]

}


module "app_module" {
  source                = "./modules/app"
  project_name          = var.project_name
  db_cluster_identifier = module.db_module.db_cluster_identifier
  log_group_name        = module.logging_module.log_gorup_name
  log_group_arn         = module.logging_module.log_group_arn
  vpc_id = module.vpc_module.vpc_id
  cidr_block            = var.cidr_block
  public_subnet_ids = module.vpc_module.public_subnet_ids
  app_subnet_ids        = module.vpc_module.app_subnet_ids
  app_port              = var.app_port

  depends_on = [
    module.vpc_module,
    module.db_module,
    module.logging_module
  ]
}
