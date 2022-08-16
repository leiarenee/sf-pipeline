#!/bin/bash

# Shell Script for State Machine Execution
export STATE_MACHINE_ARN=arn:aws:states:$PIPELINE_AWS_REGION:$PIPELINE_AWS_ACCOUNT_ID:stateMachine:$PIPELINE_STATE_MACHINE_NAME
echo State Machine ARN      : $STATE_MACHINE_ARN
echo Input Template File    : $PIPELINE_SF_TEMPLATE_FILE

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
EXECUTION_NAME=${arr[7]}

