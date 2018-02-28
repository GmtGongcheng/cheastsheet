#!/bin/bash

set -e

CMD=$1
if [ -z "$CMD" ]; then
  CMD="vagrant up"
fi
DEST="/home/young/vms"

FILES=$(find $DEST -name "Vagrantfile")

for FILE in $FILES; do
  DIR=$(dirname $FILE)
  cd $DIR && eval "$CMD" && echo "$CMD in $DIR"
done
