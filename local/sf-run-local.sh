#!/bin/bash
set -e
clear
# Stop running container
running_container=$(docker ps -q -f name=local-step-functions)
echo container runnig $running_container
if [ ! -z $running_container ]
then
  echo Stopping container $running_container
  docker stop $running_container
fi

# Remove Existing container
existing_container=$(docker container ls -a -q  -f name=local-step-functions)
echo container exists $existing_container
if [ ! -z $existing_container ]
then
  echo Removing existing container $existing_container
  docker container rm $existing_container
fi

# Run new container
echo Running new container
docker run -d -p 8083:8083 --env-file sf-local.env --name local-step-functions amazon/aws-stepfunctions-local

sf_definition=$(cat ../infra/pipeline/pipeline-state-machine.json | jq -r '.|tostring')

export SF_ENDPOINT_URL=http://localhost:8083
export SF_NAME=local-pipeline-state-machine
# Creating state machine
echo "Creating state machine local-pipeline-state-machine"
sf_arn=$(aws stepfunctions --endpoint-url $SF_ENDPOINT_URL create-state-machine \
  --definition "$sf_definition" --name "$SF_NAME" --role-arn "arn:aws:iam::012345678901:role/DummyRole" | jq -r '.stateMachineArn')


export TG_COMMAND=${1:-"$TG_COMMAND"}
export WORKSPACE_ID=${2:-"$WORKSPACE_ID"}
export STACK_FOLDER=${3:-"$STACK_FOLDER"}
export STATE_MACHINE_ARN=$sf_arn

source ./sf-test.sh $TG_COMMAND $WORKSPACE_ID $STACK_FOLDER $STATE_MACHINE_ARN $SF_NAME $SF_ENDPOINT_URL