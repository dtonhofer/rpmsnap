#!/bin/bash

# ===
# Determine "fully qualified hostname" of the machine ... hopefully correctly.
# Overengineered. Generally just calling $(hostname) would do.
# ===
# Author: David Tonhofer
# Rights: Public Domain
# This code passes "ShellCheck".

function getHostname {

   local hostname_short
   hostname_short=$(/bin/hostname --short) || {
      echo "Could not execute 'hostname --short' -- exiting" >&2
      exit 1
   }

   local hostname_long
   hostname_long=$(/bin/hostname) || {
      echo "Could not execute 'hostname' -- exiting" >&2
      exit 1
   }

   local res

   if [[ $hostname_long =~ ^"$hostname_short"\..+$ ]]; then
      # "hostname_long" is a qualified version of "hostname_short"
      # which is what we want
      res=$hostname_long
   else 
      # both hostnames are equal and "short"
      if [[ $hostname_long != "$hostname_short" ]]; then
         echo "Cannot happen: '$hostname_long' <> '$hostname_short' -- exiting" >&2; exit 1
      fi

      local domainname
      domainname=$(/bin/domainname) || {
         echo "Could not execute 'domainname' -- exiting" >&2
         exit 1
      }

      if [[ $domainname == '(none)' ]]; then
         # Change according to taste
         res="${hostname_short}.localdomain"
      else
         res="${hostname_short}.${domainname}"
      fi
   fi

   echo "$res"
}

# HN=$(getHostname)
# echo $HN

