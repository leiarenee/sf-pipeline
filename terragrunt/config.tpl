locals {

  config = "${WORKSPACE_ID}"

  ${WORKSPACE_ID} = {
    aws_region     = "${TARGET_AWS_REGION}"
    account_name   = "${TARGET_AWS_ACCOUNT_NAME}"
    aws_account_id = "${TARGET_AWS_ACCOUNT_ID}"
    aws_profile    = "${TARGET_AWS_PROFILE}"
    bucket_suffix  = "${BUCKET_SUFFIX}" 
    
    parameters = {
      REGION         = "${TARGET_AWS_REGION}"
      DOMAIN         = "${DOMAIN}"
      DNS_ZONE_ID    = "${DNS_ZONE_ID}"
      CLUSTER        = "${CLUSTER}"
      CERTIFICATE    = "${CERTIFICATE}"
    }
  }

}