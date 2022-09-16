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
  
  step_functions_name = "Pipeline-State-Machine-${random_pet.this.id}"
  lambda_source_path = "lambda-source"
  lambda_short_hash = substr(data.archive_file.lambda_source.output_sha, 0, 5)
  template_vars = {
    LAMBDA_FUNCTION_ARN = module.lambda_function_from_container_image.lambda_function_arn
  }
  sf_definition_template = templatefile("pipeline-state-machine.json", local.template_vars)
}

resource "random_pet" "this" {
  length = 2
}

# STEP Functions

module "step_function" {
  source  = "terraform-aws-modules/step-functions/aws"
  version = "2.7.0"

  name = local.step_functions_name

  type = "standard"

  definition = local.sf_definition_template

  logging_configuration = {
    include_execution_data = true
    level                  = "ALL"
  }

  trusted_entities = ["events.amazonaws.com"]

  service_integrations = {

    xray = {
      xray = true
    }

    stepfunction_Sync = {
      stepfunction = ["arn:aws:states:eu-west-1:${var.pipeline_account}:stateMachine:Pipeline-State-Machine-${random_pet.this.id}"]
      events = true

    }

    lambda = {
      lambda = [
        module.lambda_function_from_container_image.lambda_function_arn]
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
            "Sid": "IAMPassRole",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": [
              "arn:aws:iam::${var.pipeline_account}:role/AWS_Events_Invoke_Targets",
              "arn:aws:iam::${var.pipeline_account}:role/service-role/Amazon_EventBridge_Invoke_Batch_Job_Queue"
              ]

        },
        {
            "Sid": "AmazonSQSCustomAccess",
            "Effect": "Allow",
              "Action": [
              "sqs:ReceiveMessage",
              "sqs:SendMessage",
              "sqs:DeleteMessage",
              "sqs:CreateQueue",
              "sqs:DeleteMessage",
              "sqs:GetQueueAttributes",
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
              ],
            "Resource": "*"
        },
        {
            "Sid": "AWSBatchServiceEventTargetRole",
            "Effect": "Allow",
            "Action": [
                "batch:SubmitJob"
            ],
            "Resource": "*"
        }
    ]
}
EOF
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
  
  cidr_block = "172.32.0.0/16"
  enable_dns_support="true"
  enable_dns_hostnames="true"
  instance_tenancy = "default"
  tags = {
    Name = "batch"
  }
}

resource "aws_subnet" "pubsubnet" {
  vpc_id     = aws_vpc.batch.id
  cidr_block = "172.32.0.0/20"
  map_public_ip_on_launch = true
  tags = {
    Name = "batch"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id =  aws_vpc.batch.id
  tags = {
    Name = "batch"
  }

}

resource "aws_route_table" "route_table" {
  vpc_id =  aws_vpc.batch.id
  tags = {
    Name = "batch"
  }
}

resource "aws_route" "rt" {
  route_table_id            =   aws_route_table.route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id =  aws_internet_gateway.gw.id
  
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.pubsubnet.id
  route_table_id = aws_route_table.route_table.id
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
      aws_subnet.pubsubnet.id
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

# Job Definition tf_test_batch_exec_role

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "tf_test_batch_exec_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Define extra policies here
data "aws_iam_policy_document" "batch_execution_policy_document" {
    statement {
      sid = "SecretsManager"
      actions = [
        "secretsmanager:GetSecretValue",
        "kms:Decrypt"
      ]
      resources = [
        "arn:aws:secretsmanager:*:${var.pipeline_account}:secret:*",
        "arn:aws:kms:*:${var.pipeline_account}:key/*"
      ]
  }
}

resource "aws_iam_policy" "batch_execution_policy" {
  name = "batch-custom-execution-policy"
  policy = data.aws_iam_policy_document.batch_execution_policy_document.json
}

resource "aws_iam_role_policy_attachment" "batch_execution_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.batch_execution_policy.arn
}

# Job Definition

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
  "networkConfiguration":{
    "assignPublicIp" : "ENABLED"
  },
  "resourceRequirements": [
    {"type": "VCPU", "value": "1.0"},
    {"type": "MEMORY", "value": "2048"}
  ],
  "executionRoleArn": "${aws_iam_role.ecs_task_execution_role.arn}"

    
}
CONTAINER_PROPERTIES
}


  # Put this under executionRoleArn in case use it again
  # "secrets": [
  #   {
  #     "name": "PIPELINE_AWS_ACCESS",
  #     "valueFrom": "arn:aws:secretsmanager:eu-west-1:${var.pipeline_account}:secret:PIPELINE_AWS_ACCESS-Gs27T7"
  #   },
  #   {
  #     "name": "TARGET_AWS_ACCESS",
  #     "valueFrom": "arn:aws:secretsmanager:eu-west-1:${var.pipeline_account}:secret:TARGET_AWS_ACCESS-BnEnwa"
  #   },
  #   {
  #     "name": "REPO_ACCESS_TOKEN",
  #     "valueFrom": "arn:aws:secretsmanager:eu-west-1:${var.pipeline_account}:secret:REPO_ACCESS_TOKEN-aIMqzG"
  #   }
  #   ]

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

# LAMBDA (Containerised)

data "aws_region" "current" {}

data "aws_caller_identity" "this" {}

data "aws_ecr_authorization_token" "token" {}

provider "docker" {
  registry_auth {
    address  = format("%v.dkr.ecr.%v.amazonaws.com", data.aws_caller_identity.this.account_id, data.aws_region.current.name)
    username = data.aws_ecr_authorization_token.token.user_name
    password = data.aws_ecr_authorization_token.token.password
  }
}

module "docker_image" {
  #source = "terraform-aws-modules/lambda/aws//modules/docker-build"
  #version = "3.3.1"
  source = "./docker-build"
  platform = "linux/x86_64"
  create_ecr_repo = true
  ecr_repo        = "lambda-step-functions"
  ecr_repo_lifecycle_policy = jsonencode({
    "rules" : [
      {
        "rulePriority" : 1,
        "description" : "Keep only the last 10 images",
        "selection" : {
          "tagStatus" : "any",
          "countType" : "imageCountMoreThan",
          "countNumber" : 10
        },
        "action" : {
          "type" : "expire"
        }
      }
    ]
  })

  image_tag   = local.lambda_short_hash
  source_path = local.lambda_source_path
  build_args = {
    FOO = "bar"
  }
}

module "lambda_function_from_container_image" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "3.3.1"

  function_name = "lambda-step-functions"
  description   = "Containerised Lambda function for Step Functions"

  create_package = false

  ##################
  # Container Image
  ##################
  image_uri    = module.docker_image.image_uri
  package_type = "Image"
}

# For source hash calculation 
data "archive_file" "lambda_source" {
  type        = "zip"
  source_dir = local.lambda_source_path
  output_path = "lambda-source.zip"
  excludes    = split("\n", file("${local.lambda_source_path}/.dockerignore"))
}