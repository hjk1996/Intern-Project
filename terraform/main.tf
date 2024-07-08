

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
    }
  }
}


module "vpc_moudle" {
  source       = "./modules/vpc"
  cidr_block   = var.cidr_block
  project_name = var.project_name
}


