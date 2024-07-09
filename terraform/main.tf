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


module "vpc_moudle" {
  source       = "./modules/vpc"
  cidr_block   = var.cidr_block
  project_name = var.project_name
}



module "logging_module" {
  source       = "./modules/logging"
  project_name = var.project_name
}

module "db_module" {
  source = "./modules/db"
  project_name = var.project_name
  vpc_id = module.vpc_moudle.vpc_id
  db_instance_class = var.db_instance_class
  db_private_subnet_ids = module.vpc_moudle.db_private_subnet_ids
  cidr_block = var.cidr_block


  depends_on = [
    module.vpc_moudle
   ]
}

module "bastion_module" {
  source = "./modules/bastion"
  project_name = var.project_name
  vpc_id = module.vpc_moudle.vpc_id
  subnet_id = module.vpc_moudle.public_subnet_ids[0]
  ssh_key_path = var.ssh_key_path
}