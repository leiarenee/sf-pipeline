# Override paramaters for your own account
# Dublicate this file and rename it as ".override.hcl"

locals {

  # Config name - Chose from below
  config = "testing"

  # Testing Account
  testing = {
    account_name   = "leia-testing"
    aws_account_id = "553688522943"
    aws_profile    = "leia-testing"
    bucket_suffix  = "dev-leia" 
    
    parameters = {
      DOMAIN         = "testing.dev.leiarenee.io"
      DNS_ZONE_ID    = "Z0740032U1Y7EZUALC37"
      CLUSTER        = "my-testing-k8s"
      CERTIFICATE    = "arn:aws:acm:eu-west-1:553688522943:certificate/431ea958-254b-4f8c-995f-a311559fcce5"
    }
  }






}