#!/bin/bash
# Calculate progress
path_relative_to_include=$1
terrafrom_command=$2
completed_module=$(echo $path_relative_to_include| sed s/$STACK_FOLDER\\\///g)
echo
echo TERRAFORM COMMAND \"$terrafrom_command\"
echo SUB PROCESS $$ 
echo MODULE COMPLETE \"$completed_module\"

echo $completed_module >> $TG_PARRENT_DIR/completed_tasks.log
completed_tasks=($(cat $TG_PARRENT_DIR/completed_tasks.log))
module_count=${#completed_tasks[@]}
echo 
echo "Completed modules $module_count / $TG_MODULES_COUNT"
echo ------------------------------------------------------
echo 

# Calculate percentage
if [ ! -z $TG_MODULES_COUNT]
then
  progress=$(($INITIAL_PROGRESS + ($module_count * ($MODULES_FINAL_PROGRESS - $INITIAL_PROGRESS) / $TG_MODULES_COUNT)))
else
  progress=$MODULES_FINAL_PROGRESS
fi

if [ $progress -gt $MODULES_FINAL_PROGRESS ]
then
 progress=$MODULES_FINAL_PROGRESS
 echo "Progress: $progress %"
fi

# Prepare PLAN Files
if [[ $TG_COMMAND == plan ]] && [[ -f plan-state-file ]]
then
  tg_module_folder=$WORK_FOLDER/temp-job/$WORKSPACE_ID/$1
  cp ./plan-state-file $tg_module_folder
  terraform show plan-state-file > $tg_module_folder/plan-file.txt
  terraform show -json plan-state-file | jq . > $tg_module_folder/plan-file.json
  echo Plan files are created in $tg_module_folder
fi

# SQS Message Handling
if [[ ! -z $SQS_QUEUE_URL ]]
then
  # Print SQS variables
  echo
  message_body="{\"message\":{\"status\":\"Module completed '$completed_module'\",\"progress\":$progress,\"module\":\"$completed_module\"}}"
  echo SQS Message Body $(echo "$message_body" | jq .)
  echo SQS Queue URL $SQS_QUEUE_URL
  echo SQS Message Group ID $SQS_MESSAGE_GROUP_ID
  echo SQS_AWS_PROFILE $SQS_AWS_PROFILE
  echo completed_module : $completed_module
  echo

  # send sqs message
  aws --profile $SQS_AWS_PROFILE sqs send-message --queue-url "$SQS_QUEUE_URL" --message-group-id "$SQS_MESSAGE_GROUP_ID" --message-body "$message_body"
fi
