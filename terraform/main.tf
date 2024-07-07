

terraform {

  backend "s3" {
    bucket = "lguplus-intern-project-tfstate"
    key = "tfstate"
    region = "ap-northeast-2"

  }
}


provider "aws" {
  region = var.region
}


