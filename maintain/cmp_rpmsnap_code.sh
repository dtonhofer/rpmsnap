#!/bin/bash

set -o nounset

LOCAL=~qq/rpmsnap
SHOW=

if [[ ${1:-} == '--show' ]]; then
   shift
   SHOW=Y
fi  

if [[ -n ${1:-} ]]; then
   REPO=$1
else 
   echo "Pass the directory holding a clone of the github repository to compare with as argument!" >&2
   exit 1
fi

if [[ ! -d $REPO ]]; then
   echo "Directory '$REPO' does not exist -- exiting" >&2
   exit 1
fi 

for FILE in \
   sbin/get_hostname_function.sh \
   sbin/makesnap.sh \
   sbin/prelinkfix.sh \
   bin/rpmsnapcmp.pl \
   sbin/rpmsnap.pl
do
   LF=$LOCAL/$FILE
   RF=$REPO/$(basename $FILE)
   if [[ ! -f $LF ]]; then
      echo "Local file $LF does not exist -- exiting" >&2
      exit 1
   fi
   if [[ ! -f $RF ]]; then
      echo "Repository file $RF does not exist -- exiting" >&2
      exit 1
   fi
   diff --brief "$LF" "$RF"
   if [[ $? == 1 && -n $SHOW ]]; then
      diff --suppress-common-lines --side-by-side "$LF" "$RF"
   fi
done



