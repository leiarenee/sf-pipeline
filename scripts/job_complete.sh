#!/bin/bash
# Calculate progress

completed_module=$(echo $1 | sed s/$STACK_FOLDER\\\///g)
echo
echo TERRAGRUNT COMMAND \"$TG_COMMAND\"
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
progress=$(($INITIAL_PROGRESS + ($module_count * ($MODULES_FINAL_PROGRESS - $INITIAL_PROGRESS) / $TG_MODULES_COUNT)))

if [ $progress -gt $MODULES_FINAL_PROGRESS ]
then
 progress=$MODULES_FINAL_PROGRESS
 echo "Progress: $progress %"
fi

# Prepare PLAN Files
if [[ $TG_COMMAND == plan ]] && [[ -f plan-state-file ]]
then
  terraform show plan-state-file > plan-file.txt
  terraform show -json plan-state-file > plan-file.json
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
