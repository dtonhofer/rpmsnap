#!/bin/bash

# See http://tldp.org/LDP/abs/html/io-redirection.html
# See https://bugzilla.redhat.com/show_bug.cgi?id=204448

if [[ -n $1 ]]; then

   # assume a file argument

   if [[ ! -f $1 ]]; then
      echo "The passed argument '$1' does not designate a file -- exiting" >&2
      exit 1
   fi

   # set file descriptor 3 to read from file

   exec 3<"$1"

else

   # redirect stdin to file descriptor 3

   exec 3<&0

fi

# The pipe will generate all the names of the files to prelink from the file 
# passed on the command line or from stdin

FILES=`cat <&3  | perl -n -e 'if (~/prelink: (\S+):/) { print "$1\n" }' | sort --unique`

# In order to be able to count down, hoover the names up

I=0

for F in $FILES; do
   FILEARRAY[$I]=$F
   let I=$I+1
done

MAX=$I

# Actually, do not prelink one-by-one. Prelinking in one go is much, much faster (minutes vs. hours)

time prelink "${FILEARRAY[@]}"

#I=1
#
#for F in "${FILEARRAY[@]}"; do
#   echo "Prelinking '$F' ($I of $MAX)"
#   let I=$I+1
#   time prelink "$F"
#done


