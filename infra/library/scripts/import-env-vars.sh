#!/bin/bash -e
#
# This script extracts environment variables from specified files such as '.env','.det.env','../other/.env'
# Author  : Leia Rénee 
# Github  : github.com/leiarenee
# Licence : MIT
# --------------------------------------------------------------------------------

# Extracts this script's current working directory
old_script_dir=$script_dir;script_dir=$(realpath "$(dirname "$BASH_SOURCE")")

if [ -z $1 ]
then
  # Extract value of INHERIT_ENV if it exists. It will be used to set values from another repo as well
  [ -f .env ] && inherit_env=$(cat .env | grep INHERIT_ENV | sed s/INHERIT_ENV=//g)
  # .env is commited while .dev.env is ignored and used for custem overrides
  env_files=("$script_dir/.env" "$script_dir/.dev.env")
else
  env_files=($@)
fi

# Declare environment varibles from env files
for env_file in ${env_files[@]}
do
  # If file exists
  if [ -f $env_file ]
  then
    # Extract lines into array, using line break as seperater symbol.
    IFS=$'\n' env_vars=($(< $env_file))

    # For each line
    for env_var in ${env_vars[@]}
    do
      first_char=${env_var:0:1}   # Find firs character
      if [[ $first_char != "#" ]] # If it is not a comment
      then
        subst=${env_var/=/≈}      # Use parameter expansion to replace first equal sign with its twin '≈'.
        IFS='≈'                   # Set Internal Field Seperator (IFS)
        arr=($subst)              # Make it array having 2 elements.
        key=${arr[0]}             # First is variable name.
        value=${arr[1]}           # Second is variable value.
        export $key=$value
        # echo "$key=$value"
        unset IFS                 # Restore IFS
      fi
    done
  fi
done

# Restore script_dir to original value if this script is sourced
[[ "$BASH_SOURCE" != "0" && ! -z $old_script_dir ]] && script_dir=$old_script_dir || true



