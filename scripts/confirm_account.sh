#!/bin/bash
set -e
tgpath=$1
hclpath=$2
account=$3
platform=$4
tg_command=$5
aws_caller_identity_arn=$6
aws_caller_identity_user_id=$7
config=$8
region=$9
environment=${10}
state_bucket=${11}
bucket_suffix=${12}
account_name=${13}
account_id=${14}
aws_profile=${15}

function printout_info(){
  echo
  echo "Platform: $platform"
  echo "Runner: $bucket_suffix"
  echo
  echo "Running '$tg_command' command in '$region' Region for '$environment' Environment:"
  echo 
  echo "Terragrunt : "
  echo
  echo "  State Bucket:  $state_bucket"
  echo "  Command :" $tg_command
  [ ! -z $RUN_ALL   ] && echo "  Run All  : $RUN_ALL"
  [ ! -z $RUN_MODULE ] && echo "  Run Module  : $RUN_MODULE"
  echo
  echo "Repository :"
  echo
  [ ! -z $VCS_PROVIDER   ] && echo "  Vendor  : $VCS_PROVIDER"
  [ ! -z $REPO_TYPE      ] && echo "  Type    : $REPO_TYPE"
  [ ! -z $REPO_ACCOUNT   ] && echo "  Account : $REPO_ACCOUNT"
  [ ! -z $REPO_NAME      ] && echo "  Name    : $REPO_NAME"
  [ ! -z $REPO_REFERENCE ] && echo "  Ref     : $REPO_REFERENCE"
  [ ! -z $COMMIT_HASH    ] && echo "  Commit  : $COMMIT_HASH"
  echo
  echo "Workspace  : $environment"
  echo
  echo "  Account Name : $account_name"
  echo "  Account ID   : $account_id"
  echo "  AWS Profile  : $aws_profile"
  echo "  AWS Region   : $region"
  echo
  echo "  Parameters : "
  echo $account | jq .parameters
  echo
  echo AWS Caller Identity
  echo $aws_caller_identity_arn
  echo $aws_caller_identity_user_id
  echo
}


if [[ $TG_DISABLE_CONFIRM == "true" ]]
then
  [ $TG_COMMAND == "apply" ] && echo && echo "Processing $hclpath" 
  exit 0
fi

pid_file="$tgpath/.tgpid"

if [ -f "$pid_file" ]
then
  old_ppid=$(cat $pid_file)
fi
new_ppid=$PPID

if [[ $old_ppid == $new_ppid ]]
then
  # Runs on every sub process
  echo "Processing  '$hclpath'  PID:$$" 
  exit 0
else
  # Runs once in parent process
  echo Main PID: $new_ppid
  printout_info
fi

# Confirmation
echo "Do you confirm? (y/n)"
read confirm

if [[ "$confirm" == "y" ]]
then 
  echo $new_ppid > "$pid_file"
  echo "Process $new_ppid Confirmed."
  [ -f $tgpath/*.log ] && rm $tgpath/*.log
  exit 0
else
  echo "Process $new_ppid Cancelled."
  killall -9 terragrunt
  exit 1
fi