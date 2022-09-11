locals {

  # It is fetched from resource output
  project_name = join("", aws_codebuild_project.default.*.name)

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
      local.project_name,
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
}

# Log tracker
variable "log_tracker" {
  type        = map
  default     = {}
}

# Vars

variable "run_build_token" {
  description = "Change it to initiate run."
  type        = string
  default     = ""
}

variable "run_auto_build" {
  description = "If True, Build is run on every update."
  type        = bool
  default     = false
}

variable "aws_profile" {
  description = "AWS profile for use in  aws-codebuild-run.sh script"
  type = string
}

output "image_repository_url" {
  value = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.image_repo_name}:${var.image_tag}"
}