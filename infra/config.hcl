locals {

  config = "pipeline"

  pipeline = {
    aws_region     = "eu-west-1"
    account_name   = "pipeline"
    aws_account_id = "377449198785"
    aws_profile    = "leia-pipeline"
    bucket_suffix  = "github" 
    
    parameters = {
      ENVIRONMENT    = "pipeline"
      REGION         = "eu-west-1"
      DOMAIN         = "testing.dev.leiarenee.io"
      DNS_ZONE_ID    = "Z0890541BQO7OVB8F6WL"
      CLUSTER        = "my-testing-k8s"
      CERTIFICATE    = "arn:aws:acm:eu-west-1:377449198785:certificate/431ea958-254b-4f8c-995f-a311559fcce5"
      AWS_ACCOUNT_ID = "377449198785"
      PIPELINE_AWS_REGION = "eu-west-1"
      PIPELINE_AWS_ACCOUNT_ID = "377449198785"
      IAM_USER       = "cicd"
      REPO_REFERENCE = "main"
    }
  }

}