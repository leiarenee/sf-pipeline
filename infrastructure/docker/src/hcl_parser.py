"""Lambda API Backend Demo"""

import json
import re
import os

# Custom Libraries
# import library

# Lambda Environment Variable
local_dev = os.environ.get('LAMBDA_TASK_ROOT') is None

# Replace inline variables
def evaluate(string:str, replacements) -> str:
  """Replace Inline Variables

  Args:
      string (str]): Source string.

  Returns:
      [str]: Processed string.
  """
  result = string
  for key, value in replacements.items():
    result = re.sub('@{(?P<hey>' + key + ')}', value , result)
  return result

# Common HCL parser
def parse_block_hcl(block_type:str, block_data:dict,  block_name:str='',
  replacements:dict=None, indent:int=2) -> str:
  """Common HCL Parser

  Args:
      block_type (str): <locals|terraform|include|inputs|dependency|dependencies>
      block_data (dict): Block content
      block_name (str, optional): Name of the block where applicable. Defaults to ''.

  Returns:
      str: HCL formatted text.
  """
  #global indent, tf_path
  tab = indent * ' '

  hcl = f'{block_type} {block_name}{{' + '\n'

  for each, value in block_data.items():
    if isinstance(value, str): # Value is string
      hcl += tab + f'{each} = ' + evaluate(value, replacements) + '\n'
    else: # Value is object
      hcl_sub = re.sub(r'"([A-Za-z_\-0-9]+)":', r'\1 = ', json.dumps(value, indent=2))
      hcl += tab + f'{each} = ' + hcl_sub + '\n'

  hcl += '}' + '\n'

  # Return HCL
  return hcl

def dependency_block_hcl(module_data:dict, replacements:dict=None, indent:int=2,
  mock_outputs:bool=False, skip_outputs:bool=False) -> str:
  """HCL Parser for dependency block

  Args:
      module_data (dict): Dependency block data

  Returns:
      str: HCL formatted text.
  """
  #global indent, tf_path
  #tab = indent * ' '
  hcl = ''
  # Dependency Inputs
  dependency = module_data['dependency']
  for dependency_name, dependency_data in dependency.items():
    # Skip Outputs
    if skip_outputs:
      dependency_data['skip_outputs'] = True
    # Mock outputs
    if mock_outputs:
      if not 'mock_outputs' in dependency_data:
        dependency_data['mock_outputs'] = {}
      for input_name, input_value in module_data['inputs'].items():
        search_text = f'dependency.{dependency_name}.outputs.'
        search_text_found = input_value.find(search_text) >= 0
        input_value_is_basic = not re.search(r'[\]\[\{\}]', input_value)
        if search_text_found and input_value_is_basic:
          output_name = input_value[len(search_text):]
          if not output_name in dependency_data['mock_outputs']:
            dependency_data['mock_outputs'][output_name] = f'mocked'#-{input_name}'

    # Parse HCL
    hcl += parse_block_hcl(
      block_type='dependency',
      block_data=dependency_data,
      block_name=f'"{dependency_name}" ',
      replacements=replacements,
      indent=indent
      )

  # Return HCL
  return hcl

# Prapare HCL Content
def prepare_hcl(data:dict, replacements:dict=None, indent:int=2, 
  mock_outputs:bool=False, skip_outputs:bool=False) -> str:
  """Iterates over each block type and returns the complete HCL text.

  Args:
      data (dict): Data including parent block types.

  Returns:
      str: HCL formatted text.
  """

  hcl = ''
  for block_type, block_data in data.items():
    if block_type == 'dependency':
      hcl += dependency_block_hcl(data,replacements=replacements, indent=indent, 
        mock_outputs=mock_outputs, skip_outputs=skip_outputs)
    else:
      block_type_name = block_type
      if block_type == 'inputs':
        block_type_name += ' ='

      hcl += parse_block_hcl(
        block_type=block_type_name,
        block_data= block_data,
        replacements=replacements,
        indent=indent,
        )

  return hcl
