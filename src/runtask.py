import argparse
from shutil import ExecError
import sys
from io import StringIO
import library
import importlib

# Command Line Argument Parser
def argument_parser(test_args:dict=None):
  """Evaluates arguments and run functions

  Args:
      test_args (Optional[Dict]): Used in testing to pass arguments and test the output. Defaults to None.
  """
  
  global debug_mode, log_dir

  # if test_args:
    # Later this will be refactored !!!
    # Parse arguments from test_args 
    # args = parser.parse_args([])
    # for key, value in test_args.items():
    #   setattr(args, key, value)
    
    # Direct stdout to variable to return for testing
    # old_stdout = sys.stdout
    # sys.stdout = test_stdout = StringIO()

  # Get Command
  try:  
    command = sys.argv[1]
    if command[0] in ['-', '--']:
      raise 
  except:
    raise Exception('Command should be specified.')

  module_name = 'tasks'
  method = command.replace('-','_')
  args = ()
  kwargs = {'argv':sys.argv}

  # import module
  module = importlib.import_module(module_name)
  # Pass respective function to decorator
  library.safe_run(getattr(module, method))(*args,**kwargs)
      
  
  # Revert stdout to its original value and return captured output into testing platform.
  # if test_args: 
  #   sys.stdout = old_stdout
  #   return test_stdout.getvalue()

# Main Routine
if __name__ == '__main__':
  argument_parser()
  