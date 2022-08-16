#!/bin/bash

# Command Line Arguments
export TG_COMMAND=${1:-"validate"}
export WORKSPACE_ID=${2:-"testing"}
export STACK_FOLDER=${3:-"test"}
export TEST_CLIENT_INPUT_FILE=${4:-"sf-inputs.json"}
export POLL_INTERVAL=${5:-"5"}
export MAX_SQS_MESSAGES=${6:-10}
export STATE_MACHINE_ARN=${7:-"arn:aws:states:eu-west-1:377449198785:stateMachine:Pipeline-State-Machine-enabling-drake"}


echo TG Command        : $TG_COMMAND
echo Workspace ID      : $WORKSPACE_ID
echo Stack Folder      : $STACK_FOLDER
echo State Machine ARN : $STATE_MACHINE_ARN
echo Input File        : $TEST_CLIENT_INPUT_FILE
cat $TEST_CLIENT_INPUT_FILE | jq .
echo Polling Interval  : $POLL_INTERVAL
echo Max SQS Messages  : $MAX_SQS_MESSAGES
echo
echo "Starting..."
