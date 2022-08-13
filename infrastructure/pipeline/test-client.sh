#!/bin/bash
set -e

clear
echo Client Test Application Starting with following inputs

# Command Line Arguments

export COMMAND=${1:-"plan"}
export LAB_FOLDER=${2:-"test"}
export ACTLID=${1:-1}
poll=$4
simulate=$5
export LAB_DURATION=15

# Default Values
poll_interval=5
aws_account=105931657846
region=eu-west-1
state_machine_name=lab-state-machine
input_file=test-inputs.json
s3_bucket=lab-job-handler-jobs-submitted
max_sqs_message=10

# Calculate Cron Expression
# export CRON_EXPRESSION=$(python3 -m cron $lab_duration)

# Prepare Inputs
test_inputs=$(cat $input_file | envsubst | tr -d '\n' | jq -r . | sed s/\"\{/\{/ | sed s/\}\"/}/)
echo $test_inputs | jq .

# Sqs queue
echo "Command : $COMMAND"
active_lab_id=$(cat test-inputs.json | envsubst | jq -r .context.lab.activeLabId)
echo "Active Lab Id: $active_lab_id"
echo "Lab : $LAB_FOLDER"
sqs_queue_url="https://sqs.$region.amazonaws.com/$aws_account/$active_lab_id.fifo"
echo "SQS Queue URL : $sqs_queue_url"
echo "Do you confirm? (y)"
read answer

if [[ $answer != "y" ]]
then
 exit
fi

# Execute State Machine
if [ -z "$simulate" ] && [[ "$poll" != "poll" ]]
then
echo Executing lab-state-machine
aws stepfunctions start-execution \
  --state-machine-arn arn:aws:states:$region:$aws_account:stateMachine:$state_machine_name \
  --input "$test_inputs"
fi

echo "Waiting 5 Seconds for initialization of State Machine"
sleep 5

cnt=0
echo "Polling messages..."

while [ -z $end ]
do
  if [ -z "$simulate" ]
  then
    sqs_messages=$(aws sqs receive-message --queue-url $sqs_queue_url --max-number-of-messages $max_sqs_message )
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
    
    # Write status
    bar_end=$(($progress*3/10))
    #echo $bar_end
    echo -n "  [ "
    for ((i=1; i<=$bar_end; i++)); do echo -n "="; done
    for ((i=$bar_end; i<=30; i++)); do echo -n " "; done
    echo -n "] "
    echo "  Progress : $progress%    Status : $status"
    #echo -ne "    Progress : $progress%        Status : $status\033[0K\r"
    sleep 1

    if [ -z "$simulate" ]
    then
    # Delete Processed Message
    aws sqs delete-message --queue-url $sqs_queue_url --receipt-handle $receipt_handle
    fi


    end=$(echo $message | jq .end)
    
    if [[ $end == "null" ]]
    then
     unset end
    else
      echo
      echo
      echo - End of Lab State machine -
      poll_interval=0
      break
    fi

  done

  sleep $poll_interval
done

echo
echo Terraform outputs
echo
aws s3 cp --quiet s3://$s3_bucket/$active_lab_id/outputs.txt /dev/stdout
echo

