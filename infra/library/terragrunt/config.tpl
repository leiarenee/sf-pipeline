locals {

  config = "${WORKSPACE_ID}"

  ${WORKSPACE_ID} = {
    aws_region     = "${TARGET_AWS_REGION}"
    account_name   = "${TARGET_AWS_ACCOUNT_NAME}"
    aws_account_id = "${TARGET_AWS_ACCOUNT_ID}"
    aws_profile    = "${TARGET_AWS_PROFILE}"
    bucket_suffix  = "${BUCKET_SUFFIX}" 
    
    parameters = {
      ENVIRONMENT             = "${WORKSPACE_ID}"
      REGION                  = "${TARGET_AWS_REGION}"
      DOMAIN                  = "${DOMAIN}"
      DNS_ZONE_ID             = "${DNS_ZONE_ID}"
      CLUSTER                 = "${CLUSTER}"
      CERTIFICATE             = "${CERTIFICATE}"
      AWS_ACCOUNT_ID          = "${TARGET_AWS_ACCOUNT_ID}"
      PIPELINE_AWS_REGION     = "${PIPELINE_AWS_REGION}"
      PIPELINE_AWS_ACCOUNT_ID = "${PIPELINE_AWS_ACCOUNT_ID}"
      TARGET_AWS_REGION       = "${TARGET_AWS_REGION}"
      TARGET_AWS_ACCOUNT_ID   = "${TARGET_AWS_ACCOUNT_ID}"
      TARGET_AWS_PROFILE       = "${TARGET_AWS_PROFILE}"
      IAM_USER                = "cicd"
      REPO_REFERENCE          = "${REPO_REFERENCE}"
      TERRAFORM_VERSION       = "${TERRAFORM_VERSION}" 
      TERRAGRUNT_VERSION      = "${TERRAGRUNT_VERSION}" 
      VCS_PROVIDER            = "${VCS_PROVIDER}"
      REPO_ACCOUNT            = "${REPO_ACCOUNT}"
      REPO_NAME               = "${REPO_NAME}"
      REPO_REFERENCE          = "${REPO_REFERENCE}"
      REPO_TYPE               = "${REPO_TYPE}"

    }
  }

}