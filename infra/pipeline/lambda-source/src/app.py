import library
import tasks
def handler(event, context):
  """Lambda Handler Function

  Args:
    event (dict): Input parameters passed from the proxy
    context (object): Lambda context object passed from the proxy

  Returns:
    dict: Body of the returning json
  """
  if not 'args' in event:
    event['args']=[]

  if not 'kwargs' in event:
    event['kwargs']={}

  result = library.safe_run(getattr(tasks, event['function']))(*event['args'],**event['kwargs'])

  return result

if __name__ == '__main__':
  #res = handler({'function':'prepare_cron','kwargs':{'minutes':30}},{})
  #res = handler({'function':'remove_cron','kwargs':{'activeLabId':99}},{})
  res = handler({'function':'check_concurrency','kwargs':{
    'activeLabId':'11', 
    'stateMachineArn':'arn:aws:states:eu-west-1:105931657846:stateMachine:lab-state-machine',
    'jobQueue':'arn:aws:batch:eu-west-1:105931657846:job-queue/lab_queue',
    'executionId':'arn:aws:states:eu-west-1:105931657846:execution:lab-state-machine:a17aebff-8321-4996-daf0-82b8f1a3b631'
    }},{})
  print (res, "c")
  
