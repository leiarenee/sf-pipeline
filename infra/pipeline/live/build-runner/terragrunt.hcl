locals {
  global_replacements = jsondecode(file(find_in_parent_folders("replace.json")))
  local_replacements = jsondecode(file("replace.json"))
  replacements = merge(local.global_replacements, local.local_replacements)
  all_commands = ["apply", "plan","destroy","apply-all","plan-all","destroy-all","init","init-all"]

  # Get commit hash

  app_repo_name=local.local_replacements.APP_REPO_NAME
  app_repo_ref=get_env("REPO_REFERENCE")
  app_repo_url="https://github.com/${get_env("REPO_ACCOUNT")}/${local.app_repo_name}.git"
  get_version = run_cmd("--terragrunt-quiet", "${get_parent_terragrunt_dir()}/library/scripts/git-get-version.sh", local.app_repo_url, local.app_repo_ref)

  # Read general buildspec.yml file
  build_spec = file(find_in_parent_folders("buildspec.yml"))
}

terraform {
  source = "tfr:///cloudposse/codebuild/aws//.?version=1.0.0"
  extra_arguments extra_args {
    commands = local.all_commands
    env_vars = {"k8s_dependency":false}
  }
}

include {
  path = find_in_parent_folders()
}

inputs = {  
  lineage = dependency.init.outputs.lineage
  replace_variables             = merge(local.replacements,{
    IMAGE_TAG   = local.get_version
  })
  buildspec                     = local.build_spec

  # Definitions
  name = "build-${local.local_replacements.APP_NAME}-${dependency.init.outputs.lineage}"
  tags = {
    lineage = dependency.init.outputs.lineage
  }

  # Target repository (ECR)
  image_repo_name     = dependency.ecr.outputs.repository_name
  image_tag           = local.get_version

}

dependency "init" {
  config_path = "../init"
}

dependency "ecr" {
  config_path = "../ecr-pipeline"
}

