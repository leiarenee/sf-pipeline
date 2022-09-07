#!/bin/bash
set +e
log_file=log.txt

# Extract repository root
repo_root=$(git rev-parse --show-toplevel) 
scripts="$repo_root/library/scripts"

# Source Colors
source "$scripts/colors.sh"

# ------------ Poll Sqs Status Messages and Log Updates ---------------------------------------------

function fetch_logs(){
  echo Fetching Batch Logs
  $scripts/awsf logs tail /aws/batch/job --log-stream-names $LOG_STREAM_NAME --since 1d --format short > $log_file
  linesold=$lines
  lines=$(wc -l $log_file | awk '{ print $1 }')

  if [[ $linesold != $lines ]]
  then 
    echo 
    awk -v linesold=$linesold 'NR > linesold' $log_file | sed '/^$/d'
    logupdated=true
  fi
}

function check_log_stream_exists(){
  echo "Checking if Log Stream exists..."
  # Wait for initialization
  declare -i log_retry_count=0
  while [ $log_retry_count -lt $max_log_retry ]
  do
    log_retry_count=$((log_retry_count+1))
    echo "Try count: $log_retry_count"
    echo "Checking log_group $log_group"

    # Check if Log group exists
    if [[ $( $scripts/awsf logs describe-log-groups | grep -e '"logGroupName": "/aws/batch/job"') != "" ]]
    then
      log_group_exists=true
      echo -e "${GREEN}Log group exists.${NC}"
      echo "Checking stream $LOG_STREAM_NAME"
      if [[ $($scripts/awsf logs describe-log-streams --log-group-name /aws/batch/job --log-stream-name-prefix $LOG_STREAM_NAME | jq -r '.logStreams[0].logStreamName' | grep -e "$LOG_STREAM_NAME$") != "" ]]
      then
        echo -e "${GREEN}Log stream exists.${NC}"
        log_stream_exists=true
      else
        echo -e "${RED}Log stream does not exist.${NC}"
      fi
    else
      echo -e "${RED}Log group does not exist.${NC}"
    fi

    if [ $log_stream_exists ]
      then
        break
      else
        if [ $log_retry_count -lt $max_log_retry ]
          then 
            echo "Wait for stream, trying in $init_wait_time seconds."
          else
            echo
            echo -e "${RED}Error: Couldn't find log stream. Exiting.${NC}"
            exit 1
        fi
    fi
          
    sleep $init_wait_time
  done
}

# --------- Main routine ----------

declare -i lines=0
declare -i linesold=0
declare -i elapsedtime=0
logupdated=false
max_log_retry=5
log_group="/aws/batch/job"
init_wait_time=5


# SQS
echo "Waiting 5 Seconds for initialization of State Machine..."
sleep 5

cnt=0
echo "Polling..."

while [ -z $end ]
do

  sqs_messages=$($scripts/awsf sqs receive-message --queue-url $SQS_QUEUE_URL --max-number-of-messages $MAX_SQS_MESSAGES )
  messages=$(echo $sqs_messages | jq -r '.Messages[] | @base64')

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
    
    # Delete message

    $scripts/awsf sqs delete-message --queue-url $SQS_QUEUE_URL --receipt-handle $receipt_handle

    if [ -z $progress ]
    then
      # Write status
      bar_end=$(($progress*3/10))
      #echo $bar_end
      echo -n "  [ "
      for ((i=1; i<=$bar_end; i++)); do echo -n "="; done
      for ((i=$bar_end; i<=30; i++)); do echo -n " "; done
      echo -n "] "
      echo "  Progress : $progress%    Status : $status"
      [ ! -z $batch_id ] && [[ $batch_id != "null" ]] && echo "batch_id received : $batch_id"
      #echo -ne "    Progress : $progress%        Status : $status\033[0K\r"  # Write to single line
    fi
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

  AWS_BATCH_JOB_NAME=$EXECUTION_NAME
  job_summary_list=$($scripts/awsf batch list-jobs --filters name=JOB_NAME,values=$AWS_BATCH_JOB_NAME --job-queue tf-deployment-job-queue)
  batch_attempt=$(echo $job_summary_list | jq '.jobSummaryList | length' )
  batch_index=$(( $batch_attempt - 1 ))


  old_aws_batch_job_id=$AWS_BATCH_JOB_ID
  export AWS_BATCH_JOB_ID=$(echo $job_summary_list | jq -r '.jobSummaryList[0].jobId')

  describe_batch=$($scripts/awsf batch describe-jobs --jobs $AWS_BATCH_JOB_ID)

  export LOG_STREAM_NAME=$(echo $describe_batch | jq -r '.jobs[0].container.logStreamName')

  if [[ $LOG_STREAM_NAME != $old_log_stream_name ]] 
  then
    old_log_stream_name=$LOG_STREAM_NAME
    echo "Log LOG_STREAM_NAME : $LOG_STREAM_NAME"
    check_log_stream_exists
  fi

  BATCH_STATUS=$(echo $describe_batch | jq -r '.jobs[0].status')

  # Fetch Batch Log
  if [ ! -z $LOG_STREAM_NAME ] && [[ $LOG_STREAM_NAME != null ]] && [ ! -z $AWS_BATCH_JOB_ID ] 
  then
    fetch_logs
  fi

  # Check SF Status
  export SF_STATUS=$($scripts/awsf stepfunctions describe-execution --execution-arn $EXECUTION_ARN | jq -r '.status')

  if [[ $SF_STATUS == "FAILED" ]]
  then
    echo -e "${RED}$EXECUTION_NAME SF_STATUS : $SF_STATUS ${NC}"
    exit_code=1
    break
  elif [[ $SF_STATUS == "SUCCEEDED" ]]
  then
    echo -e "${GREEN}$EXECUTION_NAME SF_STATUS : $SF_STATUS ${NC}"
    break
  else 
    echo
    echo Batch Attempt $batch_attempt
    echo -e "${MAGENTA}$EXECUTION_NAME SF_STATUS : $SF_STATUS ${NC}"

    if [[ $BATCH_STATUS == FAILED ]]
    then
      batch_stat_color=${RED}
    else
      batch_stat_color=${CYAN}
    fi
    
    echo -e "$batch_stat_color$AWS_BATCH_JOB_ID BATCH_STATUS : $BATCH_STATUS ${NC}"
    echo
  fi


  sleep $POLL_INTERVAL
done

sleep 5
fetch_logs

# Write to ENV

export S3_JOB_FOLDER="s3://sf-pipeline-jobs/$WORKSPACE_ID/$EXECUTION_NAME/$AWS_BATCH_JOB_ID"

echo "S3_JOB_FOLDER = $S3_JOB_FOLDER"
echo "LOG_STREAM_NAME = aws/batch/job:$LOG_STREAM_NAME"

# Send to GITHUB_ENV
echo "AWS_BATCH_JOB_ID=$AWS_BATCH_JOB_ID" >> $GITHUB_ENV
echo "S3_JOB_FOLDER=$S3_JOB_FOLDER" >> $GITHUB_ENV
echo "LOG_STREAM_NAME=aws/batch/job:$LOG_STREAM_NAME" >> $GITHUB_ENV

[ -z $exit_code ] && exit $exit_code
