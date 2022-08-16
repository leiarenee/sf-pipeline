# ------------ Poll Sqs Status Messages and Log Updates ---------------------------------------------

# SQS
SQS_QUEUE_URL="https://sqs.$PIPELINE_AWS_REGION.amazonaws.com/$PIPELINE_AWS_ACCOUNT_ID/$EXECUTION_NAME.fifo"
echo SQS_QUEUE_URL : $SQS_QUEUE_URL

echo "Waiting 5 Seconds for initialization of State Machine..."
sleep 5

cnt=0
echo "Polling messages..."

while [ -z $end ]
do
  if [ -z "$simulate" ]
  then
    sqs_messages=$(aws --region $PIPELINE_AWS_REGION sqs receive-message --queue-url $SQS_QUEUE_URL --max-number-of-messages $MAX_SQS_MESSAGES )
    messages=$(echo $sqs_messages | jq -r '.Messages[] | @base64')
  else
    messages=$(cat messages.json | jq -r '.Messages[] | @base64')
  fi
  
  for row in $messages
  do
    cnt=$((cnt + 1))
    decoded_message=$(echo $row | base64 --decode)
    message_body=$(echo $decoded_message | jq -r .Body)
    receipt_handle=$(echo $decoded_message | jq -r .ReceiptHandle)
    message_id=$(echo $decoded_message | jq -r .MessageId)
    message=$(echo $message_body | jq -r .message)
    #echo $message
    status=$(echo $message | jq -r .status)
    progress=$(echo $message | jq .progress)
    module=$(echo $message | jq .module)
    batch_id=$(echo $message | jq -r .jobId)
    
    if [[ $batch_id != null ]] && [[ $status == "Batch_Job_Started" ]]
    then
      log_stream_name=$(aws batch describe-jobs --jobs $batch_id | jq -r '.jobs[0].container.logStreamName')
      echo Log Stream : $log_stream_name
      AWS_BATCH_JOB_ID=$batch_id
      # Get Job Id
      job_id=$!
      echo Job: $job_id
      declare -i lines=0
      declare -i linesold=0
      declare -i elapsedtime=0
      logupdated=false
    else
      unset batch_id
    fi
    set +e
    aws --region $PIPELINE_AWS_REGION sqs delete-message --queue-url $SQS_QUEUE_URL --receipt-handle $receipt_handle
    set -e
    # Write status
    bar_end=$(($progress*3/10))
    #echo $bar_end
    echo -n "  [ "
    for ((i=1; i<=$bar_end; i++)); do echo -n "="; done
    for ((i=$bar_end; i<=30; i++)); do echo -n " "; done
    echo -n "] "
    echo "  Progress : $progress%    Status : $status $batch_id"
    #echo -ne "    Progress : $progress%        Status : $status\033[0K\r"
    
    end=$(echo $message | jq .end)
    
    if [[ $end == "null" ]]
    then
     unset end
    else
      echo
      echo
      echo - End of $PIPELINE_STATE_MACHINE_NAME -
      POLL_INTERVAL=0
      break
    fi

  done

  sleep $POLL_INTERVAL
  [ ! -z $log_stream_name ] && print_log
done

