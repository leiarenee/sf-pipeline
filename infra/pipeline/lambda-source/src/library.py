"""Common Library Module"""
import json
import logging
import traceback
from functools import wraps, partial
from timeit import default_timer as timer

debug_mode=True
# Read JSON File
def read_json(json_path:str) -> str:
  """Reads JSON file

  Args:
      json_path (str): Fully qualified file name of the JSON file.

  Returns:
      dict: Dictionary object corresponding JSON data.
  """
  with open (json_path, 'r', encoding='utf-8' ) as file_object:
    return json.load(file_object)

def safe_run(func=None, **dkwargs):
  global debug_mode
  if func is None:
    return partial(safe_run, **dkwargs)

  @wraps(func)
  def wrapper(*args, **kwargs):
    
    logging.debug(f'{func.__name__} function started with following paramaters: {args} {kwargs}')
    start = timer()
    
    result = func(*args, **kwargs)
    
    end = timer()
    process_time = '{:.2f}'.format((end - start) * 1000)
    logging.debug(f'{func.__name__} function ended in {process_time} milliseconds. returned {result}')
    return result

  return wrapper


