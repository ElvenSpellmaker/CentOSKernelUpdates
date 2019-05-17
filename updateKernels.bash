#!/bin/bash

if [ -z "$1" ]; then
	>&2 echo "Please supply a valid environment name, to use as a filename suffix!"
	exit 1
fi

case $2 in
  ODD|EVEN)
  ;;
  *)
    >&2 echo "Please supply a valid type to upgrade, 'ODD' or 'EVEN'!"
    exit 1
  ;;
esac

ENVIRONMENT="$1"
TYPE="$2"
GREP_TYPE="${TYPE}_GREP"

# shellcheck disable=SC2034
ODD_GREP='[13579]'
# shellcheck disable=SC2034
EVEN_GREP='[02468]'

mkdir -p logs

FILE="logs/$ENVIRONMENT-$TYPE"
FAIL_FILE="$FILE-FAIL"

TEMP_KNOWN_HOST_FILE="/tmp/knownhosts-$ENVIRONMENT-$TYPE"

MACHINES_FILENAME="machines-$ENVIRONMENT"

if [ ! -f "$MACHINES_FILENAME" ]; then
	echo "Couldn't find a file called '$MACHINES_FILENAME'! Aborting!"
	exit 1
fi

MACHINES="$(<"$MACHINES_FILENAME")"

if [[ ! $MACHINES ]]; then
	echo "Machines file '$MACHINES_FILENAME' is emptys! Aborting!"
	exit 1
fi

while read -r machine; do
	echo "sshing to '$machine'..." | tee -a "$FILE"
	# This is so a user KnownHosts file doesn't interfere with the main script
	ssh-keyscan -H "$machine" > "$TEMP_KNOWN_HOST_FILE" 2> /dev/null

	# This is the actual line that does the update...
	ssh -qoUserKnownHostsFile="$TEMP_KNOWN_HOST_FILE" -oConnectTimeout=5 -oBatchMode=yes "$machine" 'bash -s' < ./updateSingleKernel.bash 2>&1 | tee -a "$FILE"

	# Bash only...
	# For zsh use ${pipestatus[0]}
	# For other shells PANIC!
	SSH_CODE=${PIPESTATUS[0]}

	# It's horrible, but any connection failure makes ssh report 255 also, so this could not be a "failure" as such... =|
	if [ "$SSH_CODE" -eq 255 ]; then
		echo -e "\e[31mFailed to ssh to '$machine'!\e[0m" | tee -a "$FAIL_FILE"
	elif [ "$SSH_CODE" -eq 250 ]; then
		# Rebooting returns 255 as the connection is forcibly terminated (stupid), so hope we get a 250...
		# Also, I hope this is my script exiting with this ¯\_(ツ)_/¯, hold onto your hats, reboot!
		echo "Rebooting '$machine' to finish the update..." | tee -a "$FILE"
		# Can you seriously believe that without `-n` ssh eats up _all_ the remaining `while` read input...
		ssh -nqoUserKnownHostsFile="$TEMP_KNOWN_HOST_FILE" -oBatchMode=yes "$machine" 'sudo reboot'
	elif [ "$SSH_CODE" -ne 0 ]; then
		echo -e "\e[31mAn error occured when trying to perform the kernel update on '$machine'!\e[0m" | tee -a "$FAIL_FILE"
	fi
done <<< "$(grep "[01]${!GREP_TYPE}.\+\.[cd]om$" <<< "$MACHINES")"

rm -f -- "$TEMP_KNOWN_HOST_FILE"
