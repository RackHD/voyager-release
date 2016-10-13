#!/usr/bin/env bash
# Exit the script if any command fails
set -e

# Declare bools for flag statuses
PREPAREOFFLINE=false
OFFLINE=false
DESTROY=false
PAUSE=false
UNPAUSE=false

# parse the arguments.
COUNTER=0
ARGS=("$@")
while [ $COUNTER -lt $# ]
do
    arg=${ARGS[$COUNTER]}
    let COUNTER=COUNTER+1
    nextArg=${ARGS[$COUNTER]}

    if [[ $skipNext -eq 1 ]]; then
        echo "Skipping"
        skipNext=0
        continue
    fi

    argKey=""
    argVal=""
    if [[ "$arg" =~ ^\- ]]; then
        # if the format is: -key=value
        if [[ "$argKey" =~ \= ]]; then
            argVal=$(echo "$argKey" | cut -d'=' -f2)
            argKey=$(echo "$argKey" | cut -d'=' -f1)
            skipNext=0

        # if the format is: -key value
        elif [[ ! "$nextArg" =~ ^\- ]]; then
            argKey="$arg"
            argVal="$nextArg"
            skipNext=1

        # if the format is: -key (a boolean flag)
        elif [[ "$nextArg" =~ ^\- ]] || [[ -z "$nextArg" ]]; then
            argKey="$arg"
            argVal=""
            skipNext=0
        fi
    # if the format has not flag, just a value.
    else
        argKey=""
        argVal="$arg"
        skipNext=0
    fi

    case "$argKey" in
      --prepare-offline)
          PREPAREOFFLINE=true
          shift
          ;;
      --offline)
          OFFLINE=true
          shift
          ;;
      --destroy)
          DESTROY=true
          shift
          ;;
      --pause)
          PAUSE=true
          shift
          ;;
      --unpause)
          UNPAUSE=true
          shift
          ;;
      --)
          shift
          break
          ;;
      *)
          echo "Unexpected flag passed: ${1}"
          exit 3
          ;;
    esac
done


# Start the server using the offline deps
if [ ${OFFLINE} = true ]; then
  pushd vagrant/voyager
    # Check vagrant status, must say 'poweroff'
    set +e
    ISOFF=$(vagrant status | grep -o poweroff)
    set -e
    echo "ISOFF = ${ISOFF}"
    if [ -z $ISOFF ]; then
        echo "Voyager Machine is not prepared for offline use, see --prepare-offline flag for reference."
        exit 1
    fi
    vagrant reload --provision
  popd

  pushd vagrant/rackhd
    # Check vagrant status, must say 'poweroff'
    set +e
    ISOFF=$(vagrant status | grep -o poweroff)
    set -e
    if [ -z $ISOFF ]; then
        echo "RackHD Machine is not prepared for offline use, see --prepare-offline flag for reference."
        exit 1
    fi
    vagrant reload --provision
  popd
  exit 0
fi

function vagrant_do {
  pushd vagrant/voyager
    vagrant $1
  popd

  pushd vagrant/rackhd
    vagrant $1
  popd
}

if [ ${DESTROY} = true ]; then
 vagrant_do 'destroy -f'
 echo "Vagrant machines have been destroyed."
 exit 0
fi

if [ ${UNPAUSE} = true ]; then
  vagrant_do resume
else
  # If offline is not specified, assume the user has internet connection and
  #  try to start normally
  vagrant_do up
fi

if [ ${PAUSE} = true ]; then
  vagrant_do 'suspend'
fi

# iff we're prepping for offline use, we should stop the vagrant VM's
if [ ${PREPAREOFFLINE} = true ]; then
  vagrant_do halt
  echo "Voyager has now been prepared for offline use."
  echo "When you have connected to the target hardware and are ready to resume Voyager execution, re-run this script as:"
  echo "./run_voyager.sh --offline"
fi
