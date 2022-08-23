#!/bin/bash
replace_args="{\"AWS_ACCOUNT_ID\":\"553688522943\",\"CERTIFICATE\":\"\",\"CLUSTER\":\"\",\"DNS_ZONE_ID\":\"\",\"DOMAIN\":\"\",\"ENVIRONMENT\":\"testing\",\"IAM_USER\":\"cicd\",\"PIPELINE_AWS_ACCOUNT_ID\":\"***\",\"PIPELINE_AWS_REGION\":\"eu-west-1\",\"REGION\":\"eu-west-1\",\"REPO_REFERENCE\":\"main\",\"APP_NAME\":\"client\",\"COMMIT_HASH\":\"5facf2c6fc152b5478fdacfd61a7d7fee08d0fd6\",\"CONTAINER_PORT\":8000,\"EXTERNAL_PORT\":80,\"HEALTH_CHECK_TIMEOUT\":60,\"INVALIDATE_REMOTE_CACHE\":\"false\",\"REPO\":\"https://github.com/leiarenee/sf-app.git\",\"REPO_SECRETS_MANAGER_ARN\":\"arn:aws:secretsmanager:${PIPELINE_AWS_REGION}:${PIPELINE_AWS_ACCOUNT_ID}:secret:REPO_ACCESS_TOKEN-aIMqzG\",\"REPO_SSH\":\"https://github.com/leiarenee/sf-app.git\",\"RUN_AUTO_BUILD\":\"false\",\"SLOT\":0,\"USE_REMOTE_DOCKER_CACHE\":\"true\"}"
#echo "replace_args:$replace_args"
keys=$(echo $replace_args | jq 'to_entries | .[] | .key ')


values="$(echo $replace_args | jq 'to_entries | .[] | .value ')"
echo keys
echo $keys
echo ----------
echo values
echo $values
echo ----------

set -f                      # avoid globbing (expansion of *).
keys_array=($keys)
values_array=($values)

keys_array_length=${#keys_array[@]}
values_array_length=${#values_array[@]}
echo keys_array_length $keys_array_length
echo values_array_length $values_array_length