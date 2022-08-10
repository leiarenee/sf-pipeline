"""Tasks which are called by api commands"""

# Built-in Libraries
import os
import shutil
import tempfile
import logging
import json
import subprocess
import re
import sys
import getopt
import pprint
import tarfile
import time
from typing import Dict
from subprocess import call

# External Libraries
from git import Repo
from aws_xray_sdk.core import xray_recorder, patch_all
import boto3
from botocore.exceptions import ClientError
from boto3.s3.transfer import TransferConfig

# Custom Libraries
#import cloud_functions
import library
import hcl_parser

# For dev environment
logging.basicConfig(format="[%(levelname)s] - %(asctime)s - %(name)s - : %(message)s")

# For lambda
logger = logging.getLogger()
logger.setLevel(logging.ERROR)
# xray_recorder.configure(context_missing='LOG_ERROR')
# patch_all()


def stack_folder_name():
  workspace_id = os.getenv('WORKSPACE_ID')
  #workspace_id = subprocess.run('echo $WORKSPACE_ID | envsubst', capture_output=True, text=True, shell=True).stdout.strip()
  return workspace_id

def find_groups(*args, **kwargs):
  job_folder_name='temp-job'
  os.putenv('TG_DISABLE_CONFIRM','true')
  os.chdir(f'{os.path.dirname(__file__)}/../{job_folder_name}/{stack_folder_name()}')
  cwd=os.getcwd()
  result = subprocess.run(['terragrunt', 'run-all', 'apply'], capture_output=True,text=True,input='n')

  a = re.sub(r'\n\n','\n#\n',result.stderr)
  b = re.findall('Group .\n([^#]+)', a)
  c = 0
  l = []
  g = {}
  for i in b:
    c += 1
    g[c]=[]
    d = i.split('- ')
    d.pop(0)
    for k in d:
      r = k.replace('Module ','').replace('\n','')
      s = r.replace(os.path.abspath(f'{os.path.dirname(__file__)}/../{job_folder_name}/stack/') + '/','')
      s = s.replace(cwd + '/','')
      l.append(s)
      g[c].append(s)

  return g,l

def find_modules(*args, **kwargs):
  
  os.chdir(f'{os.path.dirname(__file__)}/../temp-job/{stack_folder_name()}')
  os.putenv('TG_DISABLE_CONFIRM','true')
  result = subprocess.run(['terragrunt', 'graph-dependencies'], capture_output=True,text=True)
  b = re.findall('\"(.+)\" ;', result.stdout)
  
  return b

def print_groups(*args, **kwargs):
  groups, _ = find_groups()
  pprint.pprint (groups)

def print_groups_list(*args, **kwargs):
  _, lst = find_groups()
  pprint.pprint (lst)

def json_groups(*args, **kwargs):
  groups, _ = find_groups()
  print (json.dumps(groups))

def json_groups_list(*args, **kwargs):
  _, lst = find_groups()
  print (json.dumps(lst))

def print_modules(*args, **kwargs):
  res = find_modules()
  pprint.pprint (res)

def json_modules(*args, **kwargs):
  res = find_modules()
  print(json.dumps(res))

def delete_event(*args, **kwargs):
  """Deletes the eventbridge rule

  KwArgs:
      name (str): Eventbridge rule name
  """
  
  # Parse Commandline Arguments
  try:
    opts, args = getopt.getopt(kwargs['argv'][2:],"n:",["name="])
    for opt, arg in opts:
      if opt in ('-n', '--name'):
        rule_name = arg
    print(f'Processing Eventbridge Rule "{rule_name}"')
  except:
    print('Error: Invalid Argument')
    print (f'Usage : ./{os.path.basename(kwargs["argv"][0])} {kwargs["argv"][1]} --name <event_rule_name>')
    sys.exit(2)




  client = boto3.client('events')

  # Check if rule exists, return without error
  print(f'Checking If Event Rule "{rule_name}" exists...')
  try:
    response = client.describe_rule(Name=rule_name)
  except client.exceptions.ResourceNotFoundException:
    print (f'Event Rule "{rule_name}" does not seem to exist. That`s Ok. No Worries, if this is not a cron job.')
    return True
    
  print(f'Deleting Event Rule "{rule_name}"')
  del response['ResponseMetadata']
  pprint.pprint(response)
  
  # Fetch Targets
  response = client.list_targets_by_rule(Rule=rule_name)
  targets = response['Targets']
  ids = []
  for target in targets:
    ids.append(str(target['Id']))
  
  # Remove Targets
  if len(ids) > 0:
    response = client.remove_targets(Rule=rule_name, Ids=ids)
    print(f'Removing Targets for "{rule_name}"...')
    pprint.pprint(targets)
  else:
    print('No Targets detected.')

  # Delete Rule
  print (f'Deleting Event Rule "{rule_name}"')
  response = client.delete_rule(Name=rule_name)
  #pprint.pprint(response)
  print(f'Successfully removed "{rule_name}"')
  return response


if __name__ == '__main__':
  json_modules()
  # apply_infrastructure()