#!/bin/bash

# This executable is used to build docker image locally
set -e

[[ -f .env ]] && source .env

export APP_NAME=flask-api
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity | jq .Account -r)
export IMAGE_REPO_NAME=$APP_NAME
export SOURCE_BRANCH=$(git branch | grep "*" | sed s/\*\ //g)
export DOCKER_FILE=./Dockerfile

export USE_REMOTE_DOCKER_CACHE=false 
export UPLOAD_IMAGE=false
export FETCH_AWS_SECRETS=false
export FETCH_REPO_VERSION=false
export ECR_LOGIN=$UPLOAD_IMAGE
export ECR_STATIC_LOGIN=false
export AWS_ECR_ACCOUNT_ID=

# Project ARGS
export PYTHON_VERSION=3.9.5
export PYTHON_COMMAND=3.9

./docker/codebuild/codebuild.sh

# Clean up

# docker image prune -f > /dev/null 2>&1
# docker image ls | grep "<none>" | awk '{print $3}' | xargs docker image rm -f > /dev/null 2>&1
