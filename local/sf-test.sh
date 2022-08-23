#!/bin/bash
set -e
test_script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $test_script_dir/../.getenv
#clear
#./npy docker build push

function print_log(){
  aws logs tail /aws/batch/job --log-stream-names $log_stream_name --since 1d --format short > $log_file
  linesold=$lines
  lines=$(wc -l $log_file | awk '{ print $1 }')

  if [[ $linesold != $lines ]]
  then 
    echo 
    awk -v linesold=$linesold 'NR > linesold' $log_file | sed '/^$/d'
    logupdated=true
  fi


}

# Command Line Arguments
export TG_COMMAND=${1:-"$TG_COMMAND"}
export WORKSPACE_ID=${2:-"$WORKSPACE_ID"}
export STACK_FOLDER=${3:-"$STACK_FOLDER"}
export STATE_MACHINE_ARN=${4:-"$STATE_MACHINE_ARN"}
export STATE_MACHINE_NAME=${5:-"$PIPELINE_STATE_MACHINE_NAME"}
export SF_ENDPOINT_URL=${6:-""}

poll=$7
simulate=$8


log_file=log.txt
[ -f $log_file ] && rm $log_file
[ -f job-resources.json ] && rm job-resources.json

# Calculate Cron Expression
# export CRON_EXPRESSION=$(python3 -m cron $duration)

# Prepare Inputs

test_inputs=$(cat $test_script_dir/sf-template.json | envsubst | tr -d '\n' | jq -r . )

echo $test_inputs | jq . > test-client-inputs.json

echo
echo $test_inputs | jq .
echo
echo Polling Interval : $POLL_INTERVAL
echo Max SQS Messages : $MAX_SQS_MESSAGES
echo
echo "Starting \"$STATE_MACHINE_ARN\""
echo "Do you confirm? (y)"

read answer

if [[ $answer != "y" ]]
then
 exit
fi


# Execute State Machine
if [ -z "$simulate" ] && [[ "$poll" != "poll" ]]
then
echo Executing $STATE_MACHINE_ARN
result=$(aws --profile $PIPELINE_AWS_PROFILE --region $PIPELINE_AWS_REGION stepfunctions start-execution \
  --state-machine-arn $STATE_MACHINE_ARN --endpoint-url $SF_ENDPOINT_URL \
  --input "$test_inputs")
echo $result | jq .
execution_arn=$(echo $result | jq -r .executionArn)
IFS=":"; arr=($execution_arn); unset IFS
EXECUTION_NAME=${arr[7]}
sqs_queue_url="https://sqs.$PIPELINE_AWS_REGION.amazonaws.com/$PIPELINE_AWS_ACCOUNT_ID/$EXECUTION_NAME.fifo"
fi

echo "Waiting 5 Seconds for initialization of State Machine"
sleep 5

cnt=0
echo "Polling messages..."

while [ -z $end ]
do
  if [ -z "$simulate" ]
  then
    sqs_messages=$(aws --profile $PIPELINE_AWS_PROFILE --region $PIPELINE_AWS_REGION sqs receive-message --queue-url $sqs_queue_url --max-number-of-messages $MAX_SQS_MESSAGES )
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
    aws --profile $PIPELINE_AWS_PROFILE --region $PIPELINE_AWS_REGION sqs delete-message --queue-url $sqs_queue_url --receipt-handle $receipt_handle
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

  # Check Status
  sf_status=$(aws stepfunctions describe-execution --execution-arn $execution_arn | jq -r '.status')
  if [[ $sf_status == "FAILED" ]]
  then
    echo Step Functions FAILED
    exit 1
  else 
    echo $sf_status
  fi

  # Wait for poll interval
  sleep $POLL_INTERVAL

  # Fetch latest logs
  [ ! -z $log_stream_name ] && print_log
done

# echo
# echo Job Resources
# echo
# aws --profile $PIPELINE_AWS_PROFILE --region $PIPELINE_AWS_REGION s3 cp s3://$S3_JOBS_BUCKET/$WORKSPACE_ID/$EXECUTION_NAME/$AWS_BATCH_JOB_ID/job-resources/outputs.json job-resources.json
# cat job-resources.json | jq .
# echo

