#!/bin/bash
if [ -z $1 ] || [ -z $2 ]
then
  echo "Error Arguments must be supplied , Usage: $0 <template-file> <output-file>"
  exit 1
fi

echo Preparing $2 from $1
cat $1 | envsubst > $2
cat $2