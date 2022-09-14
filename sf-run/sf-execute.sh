#!/bin/bash
set -e
[[ $ECHO_COMMANDS == "true" ]] && set -x

script_dir=$(realpath "$(dirname "$BASH_SOURCE")")
repo_root=$(git rev-parse --show-toplevel)
scripts="$repo_root/library/scripts"

# Source Colors
source "$scripts/colors.sh"

# Fetch github token
secret_value=$($scripts/awsf --region $PIPELINE_AWS_REGION secretsmanager get-secret-value --secret-id github/workflow)
export GITHUB_TOKEN=$(echo $secret_value | jq -r '.SecretString' | jq -r .token )

# Fetch secrets for target
secret_value=$($scripts/awsf --region $PIPELINE_AWS_REGION secretsmanager get-secret-value --secret-id $TARGET_AWS_SECRET)
[ -z $TARGET_AWS_ACCESS_KEY_ID ] && export TARGET_AWS_ACCESS_KEY_ID=$(echo $secret_value | jq -r '.SecretString' | jq -r .aws_access_key_id )
[ -z $TARGET_AWS_SECRET_ACCESS_KEY ] && export TARGET_AWS_SECRET_ACCESS_KEY=$(echo $secret_value | jq -r '.SecretString' | jq -r .aws_secret_access_key )
[ -z $TARGET_AWS_REGION ] && export TARGET_AWS_REGION=$(echo $secret_value | jq -r '.SecretString' | jq -r .aws_region )
[ -z $TARGET_AWS_ACCOUNT_NAME ] && export TARGET_AWS_ACCOUNT_NAME=$(echo $secret_value | jq -r '.SecretString' | jq -r .account_name )
[ -z $TARGET_AWS_ACCOUNT_ID ] && export TARGET_AWS_ACCOUNT_ID=$(echo $secret_value | jq -r '.SecretString' | jq -r .aws_account_id )
[ -z $TARGET_AWS_PROFILE ] && export TARGET_AWS_PROFILE=$(echo $secret_value | jq -r '.SecretString' | jq -r .aws_profile )
[ -z $BUCKET_SUFFIX ] && export BUCKET_SUFFIX=$(echo $secret_value | jq -r '.SecretString' | jq -r .bucket_suffix )

# Fetch secrets for pipeline
secret_value=$($scripts/awsf --region $PIPELINE_AWS_REGION secretsmanager get-secret-value --secret-id $PIPELINE_AWS_SECRET)
[ -z $PIPELINE_AWS_ACCESS_KEY_ID ] && export PIPELINE_AWS_ACCESS_KEY_ID=$(echo $secret_value | jq -r '.SecretString' | jq -r .aws_access_key_id )
[ -z $PIPELINE_AWS_SECRET_ACCESS_KEY ] && export PIPELINE_AWS_SECRET_ACCESS_KEY=$(echo $secret_value | jq -r '.SecretString' | jq -r .aws_secret_access_key )
[ -z $PIPELINE_AWS_REGION ] && export PIPELINE_AWS_REGION=$(echo $secret_value | jq -r '.SecretString' | jq -r .aws_region )
[ -z $PIPELINE_AWS_ACCOUNT_NAME ] && export PIPELINE_AWS_ACCOUNT_NAME=$(echo $secret_value | jq -r '.SecretString' | jq -r .account_name )
[ -z $PIPELINE_AWS_ACCOUNT_ID ] && export PIPELINE_AWS_ACCOUNT_ID=$(echo $secret_value | jq -r '.SecretString' | jq -r .aws_account_id )
[ -z $PIPELINE_AWS_PROFILE ] && export PIPELINE_AWS_PROFILE=$(echo $secret_value | jq -r '.SecretString' | jq -r .aws_profile )
[ -z $BUCKET_SUFFIX ] && export BUCKET_SUFFIX=$(echo $secret_value | jq -r '.SecretString' | jq -r .bucket_suffix )

[ -z $ECR_AWS_ACCOUNT_ID ] && export ECR_AWS_ACCOUNT_ID=$PIPELINE_AWS_ACCOUNT_ID
[ -z $SQS_AWS_PROFILE ] && export SQS_AWS_PROFILE=$PIPELINE_AWS_PROFILE

function send_pr_comment(){
  echo "Updating PR Comment $COMMENT_ID with body $1"
  body=$(curl -s -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/repos/$REPO_ACCOUNT/$REPO_NAME/issues/comments/$COMMENT_ID | jq -r .body)
  echo "$body" > comment_body.txt
  #echo "current body $body"
  body="$(cat comment_body.txt | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g")"
  #body="${body//'%'/'%25'}"
  body="${body//$'\n'/'<br>'}"
  body="${body//$'\r'/}"
  
  result=$(curl -s -X PATCH -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/repos/$REPO_ACCOUNT/$REPO_NAME/issues/comments/$COMMENT_ID -d "{\"body\" : \"$body<br>$1\"}" | jq -r '.message')
  if [[ "$result" != null ]]
  then
    echo -e "${RED}github api error: $result ${NC}" 
  fi
}

# Shell Script for State Machine Execution
export STATE_MACHINE_ARN=arn:aws:states:$PIPELINE_AWS_REGION:$PIPELINE_AWS_ACCOUNT_ID:stateMachine:$PIPELINE_STATE_MACHINE_NAME
echo 
echo State Machine ARN      : $STATE_MACHINE_ARN
echo Input Template File    : $PIPELINE_SF_TEMPLATE_FILE
echo "STATE_MACHINE_ARN=$STATE_MACHINE_ARN" >> $GITHUB_ENV


# Variable Substitution
echo "Variable Substitution"
test_inputs=$(cat $script_dir/$PIPELINE_SF_TEMPLATE_FILE | envsubst | tr -d '\n' | jq -r . )
echo $test_inputs | jq . > $script_dir/aggragated-sf-inputs.json
cat $script_dir/aggragated-sf-inputs.json | jq '.aws.targetAwsAccessKeyId="---"|.aws.targetAwsSecretAccessKey="---"|.aws.pipelineAwsAccessKeyId="---"|.aws.pipelineAwsSecretAccessKey="---"' 

echo

if [[ $INTERACTIVE == true ]]
then
  echo Press y to continiue
  read answer
  [[ $answer != "y" ]] && exit 1
fi

# Step Functions
echo "State Machine Starting..."
result=$($scripts/awsf --region $PIPELINE_AWS_REGION stepfunctions start-execution --state-machine-arn $STATE_MACHINE_ARN --input "$test_inputs")
echo $result | jq .
export EXECUTION_ARN=$(echo $result | jq -r .executionArn)
IFS=":"; arr=($EXECUTION_ARN); unset IFS

export EXECUTION_NAME=${arr[7]}
export SQS_QUEUE_URL="https://sqs.$PIPELINE_AWS_REGION.amazonaws.com/$PIPELINE_AWS_ACCOUNT_ID/$EXECUTION_NAME.fifo"

echo EXECUTION_NAME=$EXECUTION_NAME
echo EXECUTION_ARN=$EXECUTION_ARN
echo SQS_QUEUE_URL : $SQS_QUEUE_URL

if [ ! -z $COMMENT_ID ]
then
  send_pr_comment "[State Machine Executed - $EXECUTION_NAME \u2705](https://$PIPELINE_AWS_REGION.console.aws.amazon.com/states/home?region=$PIPELINE_AWS_REGION#/v2/executions/details/$EXECUTION_ARN)"
fi

# Send to next steps
echo "PIPELINE_STATE_MACHINE_NAME=$PIPELINE_STATE_MACHINE_NAME" >> $GITHUB_ENV
echo "EXECUTION_NAME=$EXECUTION_NAME" >> $GITHUB_ENV
echo "SQS_QUEUE_URL=$SQS_QUEUE_URL" >> $GITHUB_ENV
echo "MAX_SQS_MESSAGES=$MAX_SQS_MESSAGES" >> $GITHUB_ENV
echo "POLL_INTERVAL=$POLL_INTERVAL" >> $GITHUB_ENV
echo "WORKSPACE_ID=$WORKSPACE_ID" >> $GITHUB_ENV
echo "EXECUTION_ARN=$EXECUTION_ARN" >> $GITHUB_ENV
echo "S3_JOB_FOLDER=$S3_JOB_FOLDER" >> $GITHUB_ENV
echo "TG_COMMAND=$TG_COMMAND" >> $GITHUB_ENV
echo "REPO_REFERENCE=$REPO_REFERENCE" >> $GITHUB_ENV
echo "ECHO_COMMANDS=$ECHO_COMMANDS" >> $GITHUB_ENV
echo "GITHUB_TOKEN=$GITHUB_TOKEN" >> $GITHUB_ENV
echo "COMMENT_ID=$COMMENT_ID" >> $GITHUB_ENV
echo "ISSUE_NUMBER=$ISSUE_NUMBER" >> $GITHUB_ENV
echo "REPO_ACCOUNT=$REPO_ACCOUNT" >> $GITHUB_ENV
echo "REPO_NAME=$REPO_NAME" >> $GITHUB_ENV
echo "REPO_PIPELINE=$REPO_PIPELINE" >> $GITHUB_ENV
echo "SQS_AWS_PROFILE=$SQS_AWS_PROFILE" >> $GITHUB_ENV
