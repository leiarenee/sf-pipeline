provider "aws" {
  region = "eu-west-1"

  # Make it faster by skipping something
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

locals {
  definition_template = file("pipeline-state-machine.json")
}

module "step_function" {
  source  = "terraform-aws-modules/step-functions/aws"
  version = "2.7.0"

  name = "Pipeline-State-Machine-${random_pet.this.id}"

  type = "standard"

  definition = local.definition_template

  logging_configuration = {
    include_execution_data = true
    level                  = "ALL"
  }

  service_integrations = {

    xray = {
      xray = true
    }

    stepfunction_Sync = {
      stepfunction = ["arn:aws:states:eu-west-1:377449198785:stateMachine:Pipeline-State-Machine-${random_pet.this.id}"]
      events = true

    }

  }
  ######################
  # Additional policies
  ######################

  attach_policy_json = true
  policy_json        = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudWatchEventsFullAccess",
            "Effect": "Allow",
            "Action": "events:*",
            "Resource": "*"
        },
        {
            "Sid": "IAMPassRoleForCloudWatchEvents",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::*:role/AWS_Events_Invoke_Targets"
        }
    ]
}
EOF
}


resource "random_pet" "this" {
  length = 2
}

# AWS Batch on Fargate
resource "aws_iam_role" "aws_batch_service_role" {
  name = "aws_batch_service_role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
        "Service": "batch.amazonaws.com"
        }
    }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "aws_batch_service_role" {
  role       = aws_iam_role.aws_batch_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBatchServiceRole"
}

resource "aws_vpc" "batch" {
  cidr_block = "10.1.0.0/16"
}

resource "aws_subnet" "batch" {
  vpc_id     = aws_vpc.batch.id
  cidr_block = "10.1.1.0/24"
}

resource "aws_security_group" "batch" {
  name = "aws_batch_compute_environment_security_group"
  vpc_id = aws_vpc.batch.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Fargate Environment

resource "aws_batch_compute_environment" "batch" {
  compute_environment_name = "Pipeline-Deployment-Jobs"

  compute_resources {
    max_vcpus = 16

    security_group_ids = [
      aws_security_group.batch.id
    ]

    subnets = [
      aws_subnet.batch.id
    ]

    type = "FARGATE"
  }

  service_role = aws_iam_role.aws_batch_service_role.arn
  type         = "MANAGED"
  depends_on   = [aws_iam_role_policy_attachment.aws_batch_service_role]
}

# Job Queue

resource "aws_batch_job_queue" "tf_deployment_queue" {
  name     = "tf-deployment-job-queue"
  state    = "ENABLED"
  priority = 1
  compute_environments = [
    aws_batch_compute_environment.batch.arn
  ]
}

# Job Definition

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "tf_test_batch_exec_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_batch_job_definition" "tf_deployment_job_definition" {
  name = "tf_pipeline_job_definition"
  type = "container"
  platform_capabilities = [
    "FARGATE",
  ]

  container_properties = <<CONTAINER_PROPERTIES
{
  "command": ["echo", "test"],
  "image": "${aws_ecr_repository.tf_docker_executor.repository_url}",
  "fargatePlatformConfiguration": {
    "platformVersion": "LATEST"
  },
  "resourceRequirements": [
    {"type": "VCPU", "value": "0.25"},
    {"type": "MEMORY", "value": "512"}
  ],
  "executionRoleArn": "${aws_iam_role.ecs_task_execution_role.arn}"
}
CONTAINER_PROPERTIES
}

# ECR

resource "aws_ecr_repository" "tf_docker_executor" {
  name                 = "tf-docker-executor"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# S3

resource "aws_s3_bucket" "sf_pipeline_jobs" {
  bucket = "sf-pipeline-jobs"

}

resource "aws_s3_bucket_acl" "sf_pipeline_jobs_acl" {
  bucket = aws_s3_bucket.sf_pipeline_jobs.id
  acl    = "private"
}