

terraform {

  backend "s3" {
    bucket = "lguplus-intern-project-tfstate"
    key = "tfstate"
    region = "ap-northeast-2"

  }

  
}


provider "aws" {
  region = var.region

  default_tags {
    tags = {
        terraform = true
    }    
  }
}


module "vpc_moudle" {
  source = "./modules/vpc"
  
}


