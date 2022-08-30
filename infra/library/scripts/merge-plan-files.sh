#!/bin/bash -e

# merge plan files
script_dir=$(realpath "$(dirname "$BASH_SOURCE")")
source $script_dir/colors.sh

s3_job_folder=${1:-$S3_JOB_FOLDER}
script_name=$(basename -- $BASH_SOURCE)

temp_folder="$script_dir/temp"
temp_script_folder="$temp_folder/$script_name"
merged="$temp_script_folder/merged-plan-files.txt"

if [ -z $S3_JOB_FOLDER ]
then
  echo S3_JOB_FOLDER should be specified as first argument or as an environment variable
  exit 1
fi

# 
# [ ! -d $temp_folder ] && mkdir $temp_folder
# [ -d $temp_script_folder ] && rm -r $temp_script_folder && mkdir $temp_script_folder


# echo "Preparing merged plan file output from s3_job_folder : $s3_job_folder"

# aws s3 cp "$s3_job_folder/plan-files" $temp_script_folder/ --recursive 

echo Terraform Plans > $merged

# Sub Folders
sf=$(find $temp_script_folder -type d)
sf=${sf//$temp_script_folder/}


for folder in $sf
do
  if [ -f $temp_script_folder/$folder/plan-file.txt ]
  then
    echo -e "\n----- ${MAGENTA}${folder/\//}${NC} Module" >> $merged # Section title
    cat $temp_script_folder/$folder/plan-file.txt >> $merged # Section Content
  fi
  # echo >> $merged # Seperator
done

cat $merged
# body="$(cat $merged | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g")"

# # Prepare for commit message
# body="${body//'%'/'%25'}"
# body="${body//$'\n'/'%0A'}"
# body="${body//$'\r'/'%0D'}" 

# # Set step output
# echo "::set-output name=body::$body"