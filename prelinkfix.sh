#!/bin/bash

if [[ -z $1 ]]; then
   echo "Give the name of a file containing prelink errors, so that the executables named may be prelinked!" >&2
   exit 1
fi

if [[ ! -f $1 ]]; then
   echo "The passed argument '$1' does not designate a file" >&2
   exit 1
fi

EXECS=`cat $1 | perl -n -e 'if (~/prelink: (\S+):/) { print "$1\n" }' | sort --unique`

for EXE in $EXECS; do
   echo "Prelinking $EXE"
   prelink $EXE
done


