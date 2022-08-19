#!/bin/bash

[[ $k8s_dependency == false ]] && exit 0
parent_terragrunt_dir=$1

if [[ $k8s_dependency != false ]]
then
  cp -R $parent_terragrunt_dir/terraform/modules/deploy-yaml .
  cp -R $parent_terragrunt_dir/terraform/modules/k8s-yaml .
  cp $parent_terragrunt_dir/terraform/providers/k8s-provider/k8s-provider.tf .
fi
