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
  active_lab_id = os.getenv('ACTIVE_LAB_ID')
  #active_lab_id = subprocess.run('echo $ACTIVE_LAB_ID | envsubst', capture_output=True, text=True, shell=True).stdout.strip()
  return active_lab_id

def create_stack(*args, **kwargs):
  """Creates the infrastructure folder

  Returns:
      [type]: [description]
  """

  indent = 2

  task_root = os.path.dirname(__file__)

  tg_path = '${get_parent_terragrunt_dir()}'
  # Read Users data
  user_id = os.getenv('USER_ID')
  user_email = os.getenv('USER_EMAIL')
  course_name = os.getenv('COURSE_NAME')
  lab_folder = os.getenv('LAB_FOLDER')
  aws_batch_id = os.getenv('AWS_BATCH_JOB_ID')
  active_lab_id = os.getenv('ACTIVE_LAB_ID')
  main_stack_folder_name=stack_folder_name()

  

  # Replacements
  replacements = {
    'tf_modules_path': f'{tg_path}/..//terraform/modules',
    'tf_components_path' : f'{tg_path}/..//terraform/components',
    'tf_labs_path': f'{tg_path}/..//terraform/labs',
    'shared_folder_path': f'{tg_path}/{main_stack_folder_name}/shared',
    'private_folder_path': f'../../private',
    'self_folder_path': f'../../self',
    'components_folder_path': f'../../components'
    }


  # Prepare Lab Stack
  lab_data = library.read_json(f'{task_root}/../terraform/labs/{lab_folder}/data/data.json')[lab_folder]
  
  # Account configuration
  account_config = os.getenv('LAB_AWS_PROFILE')
  account_dict = {
    'locals': {
      'config' : f'"{account_config}"',
      'override_active' : 'true',
      account_config : {
        'account_name': os.getenv('ACCOUNT_NAME'),
		    'aws_account_id': os.getenv('AWS_ACCOUNT_ID'),
		    'aws_profile': os.getenv('LAB_AWS_PROFILE'),
		    'bucket_suffix': os.getenv('BUCKET_SUFFIX'),
		    'parameters': {
			    'DOMAIN': os.getenv('DOMAIN'),
			    'DNS_ZONE_ID': os.getenv('DNS_ZONE_ID'),
			    'CERTIFICATE': os.getenv('CERTIFICATE')
		    }
      }
    }
  }
  account_hcl = hcl_parser.prepare_hcl(account_dict, replacements=replacements)

  tg_command = os.getenv('TG_COMMAND')
  mock_outputs = True
  skip_outputs = os.getenv('SKIP_OUTPUTS') and tg_command != 'apply' or tg_command == 'destroy'
  skip_outputs = False
  # Create Temporary folder 
  with tempfile.TemporaryDirectory() as tmp_dir:
    logger.info(f'Created temporary directory "{tmp_dir}"')

    # Create jobs folder
    job_folder = os.path.join(tmp_dir, 'job')
    os.mkdir(job_folder)

    # Write account information
    with open(os.path.join(job_folder, '.override.hcl'), 'w', encoding='utf-8') as file_object:
      file_object.write(account_hcl)

    # Create stack folder
    stack_folder = os.path.join(job_folder, main_stack_folder_name)
    os.mkdir(stack_folder)

    # Prepare job folder
    lab_stack = lab_data['stack']

    # Function for parsing 'terragrunt.hcl'
    def parse_hcl(module_name, module_data):
      print (f'Preparing Module : {module_name}')

      # Create Directory
      sub_folder = os.path.join(stack_folder, module_name)
      os.makedirs(sub_folder)

      # Prepare HCL Content
      hcl = hcl_parser.prepare_hcl(module_data['terragrunt.hcl'],
        replacements=replacements, indent=indent, 
        mock_outputs=mock_outputs, skip_outputs=skip_outputs)
      # print(hcl)

      # Write to file
      with open(os.path.join(sub_folder,'terragrunt.hcl'), 'w', encoding='utf-8') as file_object:
        file_object.write(hcl)

      # Write Json Inputs
      inputs_tfvars_json = module_data['inputs.tfvars.json']
      json_string = json.dumps(inputs_tfvars_json, indent=2)
      with open(os.path.join(sub_folder,'inputs.tfvars.json'), 'w', encoding='utf-8') as file_object:
        file_object.write(json_string)
    
    # Make a search for 'terragunt.hcl' files
    def recursive_scan(root_object, search_for='', object_path=''):
      if isinstance(root_object, Dict):
        for key, value in root_object.items():
          if key == 'initialize-tf-session':
            value['inputs.tfvars.json'] = {
                'user_id': user_id,
                'user_email': user_email,
                'course': course_name,
                'aws_batch_id' : aws_batch_id,
                'active_lab_id' : active_lab_id
            }
          if key != search_for:
            recursive_scan(value, search_for, f'{object_path}/{key}' if object_path else key)
          else:
            # Found, do the job
            #print(object_path)
            parse_hcl(object_path, root_object)

    # Search root object and its sub objects for terragrunt.hcl
    recursive_scan(lab_stack, 'terragrunt.hcl')


    
    # Write a copy to dev environment

    local_jobs_path = f'{task_root}/../temp-job'
    try:
      shutil.rmtree(local_jobs_path)
    except FileNotFoundError:
      pass
    # Copy Terraggrunt static files
    shutil.copytree(f'{task_root}/../terragrunt', f'{local_jobs_path}')
    
    # call(['cp', '-a', f'{task_root}/../terragrunt/', f'{local_jobs_path}/.'])

    shutil.copytree(f'{stack_folder}', f'{local_jobs_path}/{main_stack_folder_name}')
    shutil.copy(f'{job_folder}/.override.hcl', f'{local_jobs_path}/.override.hcl')

      
  return {}

def apply_infrastructure(*args, **kwargs):
  task_root = os.path.dirname(__file__)
  local_jobs_path = f'{task_root}/../temp-job'
  active_lab_id = subprocess.run('echo $ACTIVE_LAB_ID | envsubst', capture_output=True, text=True, shell=True).stdout.strip()
  main_stack_folder_name = active_lab_id
  stack_folder = f'{local_jobs_path}/{main_stack_folder_name}'
  
  # true if not specified
  if os.getenv('RUN_ALL'):
    run_all = os.getenv('RUN_ALL').lower() == 'true' 
  else:
    run_all = False

  # should be specified
  tg_command = os.getenv('TG_COMMAND')
  
  # false if not specified
  if os.getenv('INTERACTIVE'):
    interactive = os.getenv('INTERACTIVE').lower() == 'true' 
  else:
    interactive = False
  
  run_module = os.getenv('RUN_MODULE')

  # Run All
  if run_all:
    os.chdir(stack_folder)
    bash_command = f'terragrunt graph-dependencies && terragrunt run-all {tg_command}' \
      + (' --terragrunt-non-interactive --terragrunt-log-level error --terragrunt-debug' \
      if not interactive else "")
    os.system(bash_command)
  else:
  # Run Specific Module
    os.chdir(os.path.join(stack_folder, run_module))
    bash_command = f'terragrunt {tg_command}' \
      + (' --terragrunt-non-interactive -auto-approve --terragrunt-log-level error \
      --terragrunt-debug' if not interactive else "")
    os.system(bash_command)


  return

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
  create_stack()
  # apply_infrastructure()