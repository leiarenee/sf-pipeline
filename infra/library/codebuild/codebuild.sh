#!/bin/bash
set -e
# colors
TERM=xterm-256color
NC=`tput -T $TERM sgr0`
RED=`tput -T $TERM setaf 1`
GREEN=`tput -T $TERM setaf 2`
YELLOW=`tput -T $TERM setaf 3`
BLUE=`tput -T $TERM setaf 4`
MAGENTA=`tput -T $TERM setaf 5`
CYAN=`tput -T $TERM setaf 6`
WHITE=`tput -T $TERM setaf 7`

# If false set it empty
[[ "$USE_REMOTE_DOCKER_CACHE" == "false" ]] && USE_REMOTE_DOCKER_CACHE=""
[[ "$UPLOAD_IMAGE" == "false" ]] && UPLOAD_IMAGE=""
[[ "$SKIP_DOWNLOAD_CACHE" == "false" ]] && SKIP_DOWNLOAD_CACHE=""
[[ "$INVALIDATE_REMOTE_CACHE" == "false" ]] && INVALIDATE_REMOTE_CACHE=""
[[ "$ENFORCE_NO_CACHE" == "false" ]] && ENFORCE_NO_CACHE=""
[[ "$FETCH_AWS_SECRETS" == "false" ]] && FETCH_AWS_SECRETS=""
[[ "$FETCH_REPO_VERSION" == "false" ]] && FETCH_REPO_VERSION=""
[[ "$CHANGE_BRANCH" == "false" ]] && CHANGE_BRANCH=""
[[ "$ECR_LOGIN" == "false" ]] && ECR_LOGIN=""
[[ "$ECR_STATIC_LOGIN" == "false" ]] && ECR_STATIC_LOGIN=""


# Checkout to branch
function change_branch {
  echo
  echo -e "${GREEN}- Change branch to $SOURCE_BRANCH ${NC} "
  git checkout $SOURCE_BRANCH
  echo
}

# Fetch Secrets from secret manager
function fetch_secret {
  echo -e "${GREEN}- Feching Secret $1 from secret manager ${NC}";echo
  secret_value=$(aws secretsmanager get-secret-value --secret-id $2)
  echo "Successfully fetched $1";
  export $1=$(echo $secret_value | jq .SecretString | sed s/[\\]//g  | sed s/^\"//g | sed s/\}\"/\}/g )
}

function fetch_image_version {
  # Get version with commit hash
  export DOCKER_IMAGE_VERSION=$(git describe --tags)
  if [ -z $DOCKER_IMAGE_VERSION ]
  then
    DOCKER_IMAGE_VERSION=latest
  fi
  echo -e "${CYAN}DOCKER_IMAGE_VERSION$ ${NC}= ${YELLOW}$DOCKER_IMAGE_VERSION ${NC}"
  echo

  # Write git-info.json file
  echo -e "${CYAN}Writing 'git-info.json' ${NC}" 
  echo "{\"branch\":\"$SOURCE_BRANCH\",\"version\":\"$DOCKER_IMAGE_VERSION\"}" > .git-info.json
  echo
}

# Login to Elastic Container Registry
function ecr_login {
  echo -e "${GREEN}- Logging into ECR ${NC}"
  echo
  aws ecr get-login-password | docker login $ECR_URL -u AWS --password-stdin
  echo
}

# Login to Elastic Container Registry
function ecr_static_account_login {
  echo -e "${GREEN}- Logging into ECR Static account ${NC}"
  echo
  aws ecr get-login-password | docker login $AWS_ECR_STATIC_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com -u AWS --password-stdin
  echo
}

# ------------------------------------------------------------------------------

# Call function - 1.Parameter: Environment Varible Name, 2.Parameter: Secret Name
if [[ "$FETCH_AWS_SECRETS" == "true" ]]
then
  fetch_secret AWS_ACCESS aws-access/$AWS_ACCOUNT_ID

  export USER_AWS_ACCESS_KEY_ID=$(echo $AWS_ACCESS | jq .ACCESS_KEY_ID | sed s/\"//g )
  export USER_AWS_SECRET_ACCESS_KEY=$(echo $AWS_ACCESS | jq .SECRET_ACCESS_KEY | sed s/\"//g )
fi

export IMAGE_TIMESTAMP=ts-$(date +"%Y%m%d-%H%M%S")

export ECR_URL=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
export IMAGE_REPO_URL=$ECR_URL/$IMAGE_REPO_NAME

# Login to ECR
if [ ! -z $ECR_LOGIN ]
then
  ecr_login
fi

# Checkout to source branch
if [ ! -z $CHANGE_BRANCH ]
then
  change_branch
fi

# Fetch Repository Version
if [ ! -z $FETCH_REPO_VERSION ]
then
  fetch_image_version
else
  export DOCKER_IMAGE_VERSION=latest
fi

# Enforce no cache
if [ ! -z $ENFORCE_NO_CACHE ]
then
  echo "Enforcing 'NO CACHE' for build operations"
  NO_CACHE_ARGUMENT="--no-cache"
fi

if [ ! -z "${USE_REMOTE_DOCKER_CACHE}" ]
then
  # Use the remote cache
  echo -e "${GREEN}Remote Cache Enabled ${NC}"
  
  if [ ! -z $INVALIDATE_REMOTE_CACHE ]
  then
    echo Remote Cache Invalidated. Skipping pull installer from remote.
  else
    if [ -z $SKIP_DOWNLOAD_CACHE ]
    then
      # Pull installer cache
      echo
      echo -e "${GREEN}- Downloading latest image ${NC}"
      echo
      docker pull $IMAGE_REPO_URL:latest || true
      echo
    fi
    [[ ! -z $(docker image ls $IMAGE_REPO_URL:latest -q) ]] && cache_string="--cache-from $IMAGE_REPO_URL:latest" && echo "cache_argument : $cache_string"
    
  fi
else
  echo -e "${RED} Remote cache Disabled ! ${NC}"
  echo
fi

# Login to static account
if [ ! -z $ECR_STATIC_LOGIN ]
then
  ecr_static_account_login
fi

echo -e "${GREEN}- Building Image ${NC}"
echo
docker build $BUILD_CONTEXT \
  --file $DOCKER_FILE \
  --tag $IMAGE_REPO_URL:$DOCKER_IMAGE_VERSION \
  --tag $IMAGE_REPO_URL:latest \
  --tag $IMAGE_REPO_NAME:latest \
  $cache_string 
  
# Login to ECR
if [ ! -z $ECR_LOGIN ]
then
  ecr_login
fi

# Upload image
if [[ ! -z $UPLOAD_IMAGE ]]
then
  # Push runtime image to remote repository.
  echo
  echo -e "${GREEN}- Uploading Application Image ${NC}"
  echo
  docker push $IMAGE_REPO_URL:$DOCKER_IMAGE_VERSION

  # Upload tag:latest
  echo
  echo -e "${GREEN}- Uploading latest Tag ${NC}"
  echo
  docker push $IMAGE_REPO_URL:latest
fi

echo -e "${GREEN}- Build Complete ${NC}"


