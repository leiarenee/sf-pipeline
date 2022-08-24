locals {
  global_replacements = jsondecode(file(find_in_parent_folders("replace.json")))
  local_replacements = jsondecode(file("replace.json"))
  replacements = merge(local.global_replacements, local.local_replacements)
  all_commands = ["apply", "plan","destroy","apply-all","plan-all","destroy-all","init","init-all"]

  # Get commit hash
  commit_hash = run_cmd("${get_parent_terragrunt_dir()}/library/scripts/get_commit_hash.sh", local.local_replacements.REPO_SSH, get_env("REPO_REFERENCE"))

  # Read general buildspec.yml file
  buildspec = file(find_in_parent_folders("buildspec.yml"))
}

terraform {
  source = "${get_parent_terragrunt_dir()}//library/terraform/components/codebuild"
  extra_arguments extra_args {
    commands = local.all_commands
    env_vars = {"k8s_dependency":false}
  }
}

include {
  path = find_in_parent_folders()
}

inputs = {  
  replace_variables             = merge(local.replacements,{COMMIT_HASH=local.commit_hash})
  buildspec                     = local.buildspec
  
}



