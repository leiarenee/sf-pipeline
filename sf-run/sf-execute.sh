#!/bin/bash

# Shell Script for State Machine Execution
export STATE_MACHINE_ARN=arn:aws:states:$PIPELINE_AWS_REGION:$PIPELINE_AWS_ACCOUNT_ID:stateMachine:$PIPELINE_STATE_MACHINE_NAME
echo 
echo State Machine ARN      : $STATE_MACHINE_ARN
echo Input Template File    : $PIPELINE_SF_TEMPLATE_FILE
echo "STATE_MACHINE_ARN=$STATE_MACHINE_ARN" >> $GITHUB_ENV

# Variable Substitution
echo "Variable Substitution"
test_inputs=$(cat $PIPELINE_SF_TEMPLATE_FILE | envsubst | tr -d '\n' | jq -r . )
echo $test_inputs | jq . 
echo $test_inputs | jq . > ./sf-run/aggragated-sf-inputs.json
echo

# Step Functions
echo "State Machine Starting..."
result=$(aws --region $PIPELINE_AWS_REGION stepfunctions start-execution --state-machine-arn $STATE_MACHINE_ARN --input "$test_inputs")
echo $result | jq .
execution_arn=$(echo $result | jq -r .executionArn)
IFS=":"; arr=($execution_arn); unset IFS

export EXECUTION_NAME=${arr[7]}
export SQS_QUEUE_URL="https://sqs.$PIPELINE_AWS_REGION.amazonaws.com/$PIPELINE_AWS_ACCOUNT_ID/$EXECUTION_NAME.fifo"

echo EXECUTION_NAME=$EXECUTION_NAME
echo SQS_QUEUE_URL : $SQS_QUEUE_URL
echo S3_JOB_FOLDER : s3://sf-pipeline-jobs/$WORKSPACE_ID/$EXECUTION_NAME/$AWS_BATCH_JOB_ID

# Send to next step
echo "PIPELINE_STATE_MACHINE_NAME=$PIPELINE_STATE_MACHINE_NAME" >> $GITHUB_ENV
echo "EXECUTION_NAME=$EXECUTION_NAME" >> $GITHUB_ENV
echo "SQS_QUEUE_URL=$SQS_QUEUE_URL" >> $GITHUB_ENV
echo "MAX_SQS_MESSAGES=$MAX_SQS_MESSAGES" >> $GITHUB_ENV
echo "POLL_INTERVAL=$POLL_INTERVAL" >> $GITHUB_ENV
echo "WORKSPACE_ID=$WORKSPACE_ID" >> $GITHUB_ENV
echo "S3_JOB_FOLDER"=$S3_JOB_FOLDER" >> $GITHUB_ENV

