terraform {
  backend "s3" {
  }
}

provider "kubernetes" {
  config_path = var.eks["kubeconfig_path"]
}

provider "aws" {
  region = var.aws["region"]
}

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.eks["remote_state_bucket"]
    key    = var.eks["remote_state_key"]
    region = var.eks["remote_state_bucket_region"]
  }
}

data "aws_vpc" "vpc" {
  id = var.aws["vpc_id"]
}

data "aws_subnet_ids" "private" {
  vpc_id = data.aws_vpc.vpc.id

  tags = {
    Public = "no"
    Env    = var.env
  }
}
