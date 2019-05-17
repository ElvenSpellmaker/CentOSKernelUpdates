#!/bin/bash

# This is such a hack... HACK HACK HACK...
# Usually this wouldn't work, but it does because I use this script as stdin to
# a remote process...
sudo su

FULL_HOSTNAME=$(hostname -f)

uname -r

# Kill OMS logs with fire...
# We have had great fun with OMS filling disks...
rm -rf /var/opt/microsoft/omsagent/log &> /dev/null

FREE_MEMORY=$(($(awk '/MemFree/{print $2}' /proc/meminfo) / 1024))

# Yum is _really_ heavy on memory, so allocate some swap if we don't have much...
if [ "$FREE_MEMORY" -lt 512 ]; then
	# fallocate -l 512M /swapfile &> /dev/null # Causes problems
	dd if=/dev/zero of=/swapfile count=512 bs=1MiB &> /dev/null
	chmod 600 /swapfile &> /dev/null


	if ! mkswap /swapfile &> /dev/null; then
		>&2 echo "The machine '$FULL_HOSTNAME' couldn't allocate a swapfile, exiting! (trying to allocate because it has low RAM)"
		exit 1
	fi

	echo "Allocating swapfile for '$FULL_HOSTNAME' as the machine is running low on RAM"

	swapon /swapfile
fi

yum check-update kernel* &> /dev/null
YUM_CODE="$?"

_removeSwap()
{
	if [ $FREE_MEMORY -lt 512 ]; then
		echo "Removing the swapfile for '$FULL_HOSTNAME'"
		swapoff /swapfile
		rm -rf /swapfile
	fi
}

if [ $YUM_CODE -eq 100 ]; then
	echo "The machine '$FULL_HOSTNAME' needs an update, naughty!"

	# The clean ensures that nothing on the box is conflicting which happens more
	# than you'd think...
	yum clean all && yum update kernel* -y --disablerepo=centosplus

	UPDATE_CODE=$?

	_removeSwap

	if [ $UPDATE_CODE -ne 0 ]; then
		>&2 echo "The machine '$FULL_HOSTNAME' failed to clean or update!"
		exit 1
	fi

	# Exit with a code that hopefully isn't anywhere else to signal a reboot...
	exit 250
elif [ $YUM_CODE -eq 0 ]; then
	echo "The machine '$FULL_HOSTNAME' is already up-to-date, nice!"
	_removeSwap
else
	>&2 echo "The machine '$FULL_HOSTNAME' returned a non-zero exit code, '$YUM_CODE'!"
	_removeSwap
	exit $YUM_CODE
fi
