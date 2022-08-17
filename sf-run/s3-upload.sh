#!/bin/bash

# ------------ Send Job Resources to S3 ---------------------------------------------

echo
echo Job Resources
echo
aws --region $PIPELINE_AWS_REGION s3 cp s3://$S3_JOBS_BUCKET/$WORKSPACE_ID/$EXECUTION_NAME/$AWS_BATCH_JOB_ID/job-resources/outputs.json job-resources.json
cat job-resources.json | jq .
echo