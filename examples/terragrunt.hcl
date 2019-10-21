include {
  path = "${find_in_parent_folders()}"
}

terraform {
  source = "github.com/clusterfrak-dynamics/terraform-aws-eks-rds.git?ref=v1.0.0"

  before_hook "kubeconfig" {
    commands = ["apply", "plan"]
    execute  = ["bash", "-c", "cp ${get_terragrunt_dir()}/../eks/kubeconfig kubeconfig"]
  }
}

locals {
  aws_region   = basename(dirname(get_terragrunt_dir()))
  env          = "production"
  db_name      = replace(basename(get_terragrunt_dir()), "postgres-", "")
  custom_tags  = yamldecode(file("${get_terragrunt_dir()}/${find_in_parent_folders("common_tags_unity.yaml")}"))
}

inputs = {

  aws = {
    "region" = local.aws_region
    "vpc_id" = "vpc-id"
  }

  eks = {
    "kubeconfig_path"            = "./kubeconfig"
    "remote_state_bucket"        = "terraform-remote-state"
    "remote_state_key"           = "${local.aws_region}/eks"
    "remote_state_bucket_region" = "eu-west-1"
  }

  env = local.env

  db_identifier = local.db_name
  db_name       = replace(local.db_name, "-", "")
  db_username   = replace(local.db_name, "-", "")

  db_tags = merge(
      {
        "Env" = local.env
      },
      local.custom_tags
  )

  db_deletion_protection = false
  db_multi_az            = false

  inject_secret_into_ns = [
    "${local.db_name}-${local.env}",
  ]

}
