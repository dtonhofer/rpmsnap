#!/bin/bash

# ----
# Determine fully qualified hostname of the machine
# ----

function getHostname {

   local hostname_short=`/bin/hostname --short`

   if [ $? -ne 0 ]; then 
      echo "Could not execute 'hostname --short' -- exiting" >&2; exit 1
   fi

   local hostname_long=`/bin/hostname`

   if [ $? -ne 0 ]; then
      echo "Could not execute 'hostname' -- exiting" >&2; exit 1
   fi

   if [[ $hostname_long =~ ^"$hostname_short"\..+$ ]]; then
      # "hostname_long" is a qualified version of "hostname_short"
      echo $hostname_long
   else 
      # both hostnames are "short" (and are equal)
      if [[ $hostname_long != $hostname_short ]]; then
         echo "Cannot happen: '$hostname_long' <> '$hostname_short' -- exiting" >&2; exit 1
      fi

      local domainname=`/bin/domainname`

      if [ $? -ne 0 ]; then
         echo "Could not execute 'domainname' -- exiting" >&2; exit 1
      fi

      if [[ domainname == '(none)' ]]; then
         # Change according to taste
         echo "${hostname_short}.localdomain"
      else
         echo "${hostname_short}.${domainname}"
      fi
   fi
}

# HN=$(getHostname)
# echo $HN

