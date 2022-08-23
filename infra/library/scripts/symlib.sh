#!/bin/bash
# Create symlinks in root of infra
cwdir=$(printf '%s\n' "${PWD##*/}")
[[ $cwdir != "infra" ]] && echo Current directory should be infra && exit
tgdir=library/terragrunt
for file in $(ls $tgdir)
do
  [ ! -h $file ] && echo Symlink created for $file && ln -s $tgdir/$file
done
