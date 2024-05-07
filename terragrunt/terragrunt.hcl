locals {
  environments = ["dev", "prod"]
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
  provider "aws" {
    region = "us-east-2"
  }
  EOF
}

remote_state {
  backend = "s3"
  config = {
    encrypt        = true
    bucket         = ""
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

terraform {
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
    required_var_files = concat([
        "${get_parent_terragrunt_dir()}/account.tfvars"
      ], [for env in local.environments : "${get_parent_terragrunt_dir()}/${env}/environment.tfvars"])

    optional_var_files = [
      "${get_parent_terragrunt_dir()}/${path_relative_to_include()}/common.tfvars",
    ]
  }

}
