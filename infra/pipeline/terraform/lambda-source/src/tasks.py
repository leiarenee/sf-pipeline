from pickle import TRUE
import json
from datetime import datetime, timedelta
import boto3

def prepare_cron(minutes=10):
  """Prepares Cron Expression adding time interval with relative to current time

  Args:
      minutes (int): Time interval in minutes to be added to current time

  Returns:
      str: Cron Expression
  """

  dt = datetime.utcnow() + timedelta(minutes=minutes)
  return f'cron({dt.minute} {dt.hour} {dt.day} {dt.month} ? {dt.year})'

def remove_cron(activeLabId=''):
  """Removes Cron Job

  Args:
      activeLabId (str): Active Lab Id

  Returns:
      dict: Response object
  """

  client = boto3.client('events')
  try:
    response = client.remove_targets(Rule=f'SF-Cron-{activeLabId}',Ids=['1'])
  except:
    pass
  response = client.delete_rule(Name=f'SF-Cron-{activeLabId}')
  return response

def check_concurrency(workspaceId='',stateMachineArn='',jobQueue='',executionId=''):
  """Checks step functions and batch if an instance with workspaceId is running

  Args:
      workspaceId (str): Workspace Id 
      stateMachineArn (str): State Machine ARN
      jobQueue (str): Batch Job Queue Name

  Returns:
      bool: True if instance is found, otherwise False
  """
  # Sub routine for Step Functions
  def check_step_functions():
    client = boto3.client('stepfunctions')
    response_list = client.list_executions(
      stateMachineArn=stateMachineArn,
      statusFilter='RUNNING'
    )
    for sf in response_list['executions']:
      if executionId == sf['executionArn']:
        continue
      response_describe= client.describe_execution(executionArn=sf['executionArn'])
      inputs = json.loads(response_describe['input'])
      try:
        wSpaceId = inputs['workspace']['workspaceId']
      except KeyError:
        continue
      if wSpaceId == workspaceId:
        return True
    return False
  
  # Sub routine for Batch
  client = boto3.client('batch')
  def check_batch(check_status='RUNNING'):
    response_list_jobs = client.list_jobs(
      jobQueue=jobQueue,
      jobStatus=status,
      maxResults=3,
    )
    job_ids = [k['jobId'] for k in response_list_jobs['jobSummaryList']]
    if len(job_ids) == 0:
      return False
    response_describe_jobs = client.describe_jobs(jobs=job_ids)
    jobs = response_describe_jobs['jobs']
    for index in range(len(jobs)):
      job = jobs[index]
      env_vars = job['container']['environment']
      for k in range(len(env_vars)):
        env = env_vars[k]
        if env['name'] == 'ACTIVE_LAB_ID' and env['value'] == workspaceId:
          return True
        
    return False

  # Main Routine
  check_status_list = ['SUBMITTED','PENDING','RUNNABLE','STARTING','RUNNING']

  # Check SF
  if check_step_functions():
    return True

  # Check Batch
  for status in check_status_list:
    if check_batch(check_status = status):
      return True
  
  return False