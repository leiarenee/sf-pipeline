
locals {
  repository_name = var.application_name
  build_name      = local.repository_name
  tagPrefixList   = concat(var.tagPrefixList, [])
  image_tag       = var.image_tag

  log_tracker_defaults = {
    initial_timeout   = 300
    update_timeout    = 300
    sleep_interval    = 30
    init_wait_time    = 15
    max_retry_count   = 15
    print_dots        = false
  }

  log_tracker = merge(local.log_tracker_defaults, var.log_tracker)
  
}
 

resource "null_resource" "codebuild_provisioner" {
    triggers = {
      value = var.run_auto_build ? timestamp() : var.run_build_token
    }
  

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = join(" ",[
      "scripts/aws-codebuild-run.sh",
      module.build.project_name,
      var.aws_profile,
      var.aws_region,
      local.log_tracker.print_dots,
      local.log_tracker.initial_timeout,
      local.log_tracker.update_timeout,
      local.log_tracker.sleep_interval,
      local.log_tracker.init_wait_time,
      local.log_tracker.max_retry_count
    ])
    # Arguments
    # <codebuild-project-name> <aws-profile> <aws-region> <print-dots> <initial-timeout> <update-timeout> <sleep-interval> <init-wait-time> <max-retry-count>
  }

  depends_on = [module.build, aws_ecr_repository.ecr_repo]
}




