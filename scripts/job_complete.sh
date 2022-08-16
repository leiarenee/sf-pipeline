#!/bin/bash
# Calculate progress

completed_module=$(echo $1 | sed s/$STACK_FOLDER\\\///g)
echo
echo TERRAGRUNT-PROCESS-COMPLETE $completed_module
#pwd
echo $completed_module >> $TG_PARRENT_DIR/completed_tasks.log
completed_tasks=($(cat $TG_PARRENT_DIR/completed_tasks.log))
module_count=${#completed_tasks[@]}
echo 
echo "Completed modules $module_count / $TG_MODULES_COUNT"
echo ------------------------------------------------------
echo 
[ -z $SQS_QUEUE_URL ] && exit 0
progress=$(($INITIAL_PROGRESS + ($module_count * ($MODULES_FINAL_PROGRESS - $INITIAL_PROGRESS) / $TG_MODULES_COUNT)))
if [ $progress -gt $MODULES_FINAL_PROGRESS ]
then
 progress=$MODULES_FINAL_PROGRESS
fi

echo "Progress: $progress %"
echo
message_body="{\"message\":{\"status\":\"Module completed '$completed_module'\",\"progress\":$progress,\"module\":\"$completed_module\"}}"
echo "Sending SQS Message $message_body"
echo

# send sqs message
result=(aws --profile $SQS_AWS_PROFILE sqs send-message --queue-url "$SQS_QUEUE_URL" --message-group-id "$SQS_MESSAGE_GROUP_ID" --message-body $message_body)
