#!/bin/bash -e
#
# This script prepares version tag using commit hash and tag name
# Author  : Leia Rénee 
# Github  : github.com/leiarenee
# Licence : MIT
# --------------------------------------------------------------------------------


# Extracts this script's current working directory
old_script_dir=$script_dir;script_dir=$(realpath "$(dirname "$BASH_SOURCE")")

# Define colors
source $script_dir/colors.sh

# Define variables
repo=$1
branch=${2:-main}

if [ -z $repo ]
then
  echo -e "${RED}Repository address must be specified as first argument."
  exit 1
fi

# Get commit hash
commit=$(git ls-remote $repo $branch | cut -f 1 )

if [[ -z "$commit" ]] 
then
  echo
  echo -e "${RED}Error : could not find commit hash${NC}"
  echo "Repository : ${BLUE}$repo${NC}"
  echo "Branch : ${CYAN}$branch${NC}"
  echo
  exit 1
fi

sha=${commit:0:7}
tag=$(git ls-remote $repo | sort -Vk2 | grep $commit | grep tag | cut -d '/' -f 3)

if [ -z $tag ]
then
  version=$sha
else 
  version=$tag-$sha 
fi

# Print output
echo $version


# Restore script_dir to original value if this script is sourced
[[ "$BASH_SOURC"E != "0" ]] && [ ! -z "$old_script_dir" ] && script_dir="$old_script_dir" || true

