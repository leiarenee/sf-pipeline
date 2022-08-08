terraform {
  extra_arguments "common" {
    commands  = get_terraform_commands_that_need_vars()
    arguments = [
      "-var", "region=${get_env("region", "eu-west-1")}"
    ]
    optional_var_files = [
      "${get_terragrunt_dir()}/../common.hcl"
    ]
  }
}

remote_state {
  backend = "s3"
  config = {
    bucket         = "tfstate-interview-chainlink"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "${get_env("region", "eu-west-1")}"
    encrypt        = true
    dynamodb_table = "tf-locks-chainlink"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  backend "s3" {}
}
provider "aws" {
  region = var.region
}
variable "region" {
  type = string
}
EOF
}