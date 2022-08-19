#!/bin/bash

parent_terragrunt_dir=$1
cp -R $parent_terragrunt_dir/library/scripts/ scripts
echo $parent_terragrunt_dir
pwd


if [[ $k8s_dependency != false ]]
then
  cp -R $parent_terragrunt_dir/library/terraform/modules/deploy-yaml .
  cp -R $parent_terragrunt_dir/library/terraform/modules/k8s-yaml .
  cp $parent_terragrunt_dir/library/terraform/providers/k8s-provider/k8s-provider.tf .
fi
