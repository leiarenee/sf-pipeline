#!/bin/bash



exclude="DIRENV"
IFS=$'\n' env_vars=($(env | grep -vE $exclude | sed 's/"/\\"/g' | sed 's/\\\\/\\/g'))
    
for env_var in ${env_vars[@]}
do
  subst=${env_var/=/≈};IFS='≈';arr=($subst);key=${arr[0]};value=${arr[1]};unset IFS

    json="$json\"$key\":\"$value\","
done

# remove last comma and add main curly brackets
json="{${json%\,*}}"

# Ref :
# ${tmp#*_}   # remove prefix ending in "_"
# ${tmp%_*}   # remove prefix ending in "_"
# len=${#env_vars[@]} # number of env vars

# Give JSON out filtered by jq

function prepare_output(){
  if [[ $1 == "string" ]]
  then
    echo $json | sed 's/"/\\"/g'
  else
    echo $json | jq .
  fi
}


# write also to file if $2 exists
if [ ! -z $2 ]
then 
  prepare_output $1
else
  prepare_output $1 | tee $2
fi

