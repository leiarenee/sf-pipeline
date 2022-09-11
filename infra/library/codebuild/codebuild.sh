#!/bin/bash
set -e
set -x
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
[[ $USE_REMOTE_DOCKER_CACHE == false ]] && USE_REMOTE_DOCKER_CACHE="" 
[[ "$UPLOAD_IMAGE" == "false" ]] && UPLOAD_IMAGE=""
[[ "$SKIP_DOWNLOAD_CACHE" == "false" ]] && SKIP_DOWNLOAD_CACHE=""
[[ "$INVALIDATE_REMOTE_CACHE" == "false" ]] && INVALIDATE_REMOTE_CACHE=""
[[ "$ENFORCE_NO_CACHE" == "false" ]] && ENFORCE_NO_CACHE=""
[[ "$ECR_LOGIN" == "false" ]] && ECR_LOGIN=""


# Login to Elastic Container Registry
function ecr_login {
  echo -e "${GREEN}- Logging into ECR ${NC}"
  echo
  aws ecr get-login-password | docker login $ECR_URL -u AWS --password-stdin
  echo
}

# ------------------------------------------------------------------------------

export ECR_URL=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
export IMAGE_REPO_URL=$ECR_URL/$IMAGE_REPO_NAME

ecr_login

# Enforce no cache
if [ ! -z $ENFORCE_NO_CACHE ]
then
  echo "Enforcing 'NO CACHE' for build operation"
  no_cache_argument="--no-cache"
fi

if [ ! -z $USE_REMOTE_DOCKER_CACHE ]
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
      docker pull $IMAGE_REPO_URL:install-cache || true
      echo
    fi
    [[ ! -z $(docker image ls $IMAGE_REPO_URL:latest -q) ]] && cache_string="--cache-from $IMAGE_REPO_URL:latest" && echo "cache_argument : $cache_string"
    [[ ! -z $(docker image ls $IMAGE_REPO_URL:install-cache -q) ]] && install_cache_string="--cache-from $IMAGE_REPO_URL:instal-cache" && echo "install_cache_argument : $install_cache_string"
    
  fi
else
  echo -e "${RED} Remote cache Disabled ! ${NC}"
  echo
fi


# ---------- BUILD -----------

echo -e "${GREEN}- Building Image ${NC}"
echo
docker build $BUILD_CONTEXT --file $DOCKER_FILE \
  --tag $IMAGE_REPO_URL:latest --tag $IMAGE_REPO_URL:$IMAGE_TAG \
  --tag $IMAGE_REPO_NAME:latest --tag $IMAGE_REPO_NAME:$IMAGE_TAG \
  --build-arg TERRAFORM_VERSION=$TERRAFORM_VERSION --build-arg TERRAGRUNT_VERSION=$TERRAGRUNT_VERSION \
  $cache_string $install_cache_string $no_cache_argument

echo -e "${CYAN}Docker Image Repository URL${NC} : ${GREEN}$IMAGE_REPO_URL:$IMAGE_TAG${NC}"
echo -e "${CYAN}Local image${NC} : ${GREEN}$APP_NAME:$IMAGE_TAG ${NC} "

# Upload image
if [[ ! -z $UPLOAD_IMAGE ]]
then

  # Login to ECR
  if [ ! -z $ECR_LOGIN ]
  then
    ecr_login
  fi

  # Push runtime image to remote repository.
  echo
  echo -e "${GREEN}- Uploading Application Image ${NC}"
  echo
  docker push $IMAGE_REPO_URL:$IMAGE_TAG

  # Upload tag:latest
  echo
  echo -e "${GREEN}- Uploading latest Tag ${NC}"
  echo
  docker push $IMAGE_REPO_URL:latest
fi

# Build install stage
if [[ $(echo $IMAGE_REPO_NAME | grep client ) ]]
then
  docker build $BUILD_CONTEXT --file $DOCKER_FILE --target install --tag $IMAGE_REPO_URL:install-cache
  docker push $IMAGE_REPO_URL:install-cache
fi



echo -e "${GREEN}- Build Complete ${NC}"


