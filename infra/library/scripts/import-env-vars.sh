#!/bin/bash -e
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
pwd
echo $inherit_env
repo_root=$( cd $script_dir/../../.. "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo $repo_root
[ ! -z $repo_root ] && export REPO_ROOT=$repo_root
export WORK_FOLDER=$REPO_ROOT/$WORK_FOLDER_NAME
export AWS_PAGER=""
[ -f .env ] && inherit_env=$(cat .env | grep INHERIT_ENV | sed s/INHERIT_ENV=//g)

# Declare default variables
env_files=("$REPO_ROOT/.env" "$inherit_env/.env" ".env" ".dev.env")
IFS=$'\n'

# Declare environment varibles from env files
for env_file in ${env_files[@]}
do
  if [ -f $env_file ]
  then
    IFS=$'\n' env_vars=($(< $env_file))
    for env_var in ${env_vars[@]}
    do
      
      first_char=${env_var:0:1}
      if [[ $first_char != "#" ]]
      then
        # IFS='=';arr=($env_var);key=${arr[0]};unset arr[0];len=${#arr[@]};value=${arr[@]};unset IFS
        subst=${env_var/=/≈};IFS='≈';arr=($subst);key=${arr[0]};value=${arr[1]};unset IFS #new one liner ;-)
        export $key="$value"
        # [[ $1 != quiet ]] && echo "$key=$value"
        
      fi
    done
  fi
done

unset IFS


