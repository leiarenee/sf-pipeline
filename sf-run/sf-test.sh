#!/bin/bash
set -e
clear
# Extract running script folder
old_script_dir=$script_dir;script_dir=$(realpath "$(dirname "$BASH_SOURCE")")

# Extract repository root
repo_root=$(git rev-parse --show-toplevel) 

# Source Colors
source $repo_root/infra/library/scripts/colors.sh

# Source env vars
source $repo_root/.getenv

# Initialize github env file
if [ -z $GITHUB_ENV ]
then
  export GITHUB_ENV="$script_dir/github.env"
  echo "# Simulated GITHUB Environment Variables" > $GITHUB_ENV
fi

# Run Pipeline
echo -e "\n${GREEN}Step1: Executing Step Functions.${NC}"
$script_dir/sf-execute.sh

# Transfer github environment variables
echo -e "\n${GREEN}Transfering varibles to next step.${NC}"
cat $GITHUB_ENV
source $script_dir/../.getenv $GITHUB_ENV

# Trace
echo -e "\n${GREEN}Step2: Tracing Step Functions ${NC}"
$script_dir/sqs-poll.sh

# Restore script_dir to original value if this script is sourced
[[ "$BASH_SOURCE" != "0" && ! -z $old_script_dir ]] && script_dir=$old_script_dir || true
