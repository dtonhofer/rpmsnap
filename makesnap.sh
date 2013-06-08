#!/bin/bash

# ==================================================================================
# Script to run "rpmsnap.pl", presumably from crontab
#
# In root's crontab, one may have for example:
#
# 00 17 */3 * * $DIR/rpm/sbin/makesnap.sh 2>/dev/null
# ==================================================================================

set -o nounset

# Set the installation directory; change this as desired

DIR=/usr/local/toolbox/rpmsnap

# Underneath "DIR", things should presumable look like this:
# .
# ├── bin
# │   └── rpmsnapcmp.pl
# ├── data
# │   └── yourhost.yourdomain.yourtld
# │       ├── rpmsnap.2013-01-07_17:00:01.txt
# │       ├── rpmsnap.2013-03-04_17:00:02.txt
# │       ├── rpmsnap.2013-04-07_17:00:01.txt
# │       └── rpmsnap.2013-06-07_17:00:01.txt
# └── sbin
#     ├── makesnap.sh
#     ├── prelinkfix.sh
#     └── rpmsnap.pl

NOW=`date +%Y-%m-%d_%H:%M:%S`          # used in creating the suffix of files written to DATADIR
RPMSNAP="${DIR}/sbin/rpmsnap.pl"       # the perl script that creates the list of packages
DATADIR="${DIR}/data/`hostname`"       # result files of rpmsnap.pl go here

# ----
# Function to decide what to do with a new file
# ----

function keepOrDelete {
   local LATEST=$1
   local FILE_NEW=$2
   local FILE_FINAL=$3
   if [[ -n ${LATEST} ]]; then
      diff "${FILE_NEW}" "${LATEST}" > /dev/null
      local RETVAL=$?
      case ${RETVAL} in
         0)
            echo "No differences found between '${FILE_NEW}' and '${LATEST}' -- deleting '${FILE_NEW}'" >&2
            /bin/rm "${FILE_NEW}"      
         ;;
         1)
            echo "Differences found between '${FILE_NEW}' and '${LATEST}' -- keeping '${FILE_NEW}'" >&2
            /bin/mv "${FILE_NEW}" "${FILE_FINAL}"
         ;;
         2)
            echo "Some problem occurred with 'diff' -- exiting" >&2
            exit 1
         ;;
         *)
            echo "Unexpected returnvalue ${RETVAL} from 'diff' -- exiting" >&2
            exit 1
         ;;
      esac
   else 
      # No latest - just keep current
      /bin/mv "${FILE_NEW}" "${FILE_FINAL}"
   fi
}

# ----
# Create the DATADIR into which files are saved if needed.
# ----

if [[ ! -d "$DATADIR" ]]; then
   echo "Directory '$DATADIR' does not exist - creating it" >&2 
   mkdir "$DATADIR"
   if [[ $? != 0 ]]; then
      echo "Could not create directory '$DATADIR' -- exiting" >&2
      exit 1
   fi
fi

# ----
# Run "rpmsnap.pl"
#
# The STDOUT is captured in the OUTFILE_NEW; later we will decide whether we will keep it; if there
# are no changes relative to an earlier file, there is no reason to do so.
#
# The STDERR is cpatured in the ERRFILE_NEW; later we will decide whether we will keep it; if there
# are no changes relative to an earlier file, there is no reason to do so.
#
# The ERRFILE_NEW lists "prelink" errors, which can be solved using the following pipe:
# cat $ERRFILE | perl -n -e 'if (~/prelink: (\S+):/) { print "$1\n" }' | sort --unique | xargs prelink
# ----

OUTFILE="${DATADIR}/rpmsnap.${NOW}.txt"
OUTFILE_NEW="${OUTFILE}.new"

ERRFILE="${DATADIR}/rpmsnap.${NOW}.err"
ERRFILE_NEW="${ERRFILE}.new"

echo "'rpmsnap' information goes to '${OUTFILE_NEW}', errors go to '${ERRFILE_NEW}'" >&2

"${RPMSNAP}" --verify >"${OUTFILE_NEW}" 2>"${ERRFILE_NEW}"

if [[ $? != 0 ]]; then
   echo "Problem running ${RPMSNAP} -- exiting." >&2
   echo "Errors may be in '${ERRFILE_NEW}'" >&2
   exit 1
fi

# ----
# Compare contents of $OUTFILE_NEW with the latest $OUTFILE created.
# The latest $OUTFILE is simply obtained by lexicographical sorting of the contents of $DATADIR
# Note that LATEST may not exist!
# ----

LATEST_OUT=`ls ${DATADIR}/rpmsnap.*.txt 2>/dev/null | sort | tail -1`

keepOrDelete "${LATEST_OUT}" "${OUTFILE_NEW}" "${OUTFILE}"

LATEST_ERR=`ls ${DATADIR}/rpmsnap.*.err 2>/dev/null | sort | tail -1`

keepOrDelete "${LATEST_ERR}" "${ERRFILE_NEW}" "${ERRFILE}"



