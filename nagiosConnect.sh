#!/bin/bash

tsNow=$(date +%s)

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

scriptName="zimbraBackup.sh"
########################################

USAGE="Usage: $(basename $0) [-h] [-n nagios log] [-l lar run] [-t time interval]\n
        -n [FILE] Path to nagios log - zimbraSnapshot.log.\n
        -l [FILE] Lastrun file.\n
        -t [INT] Time interval between executions.\n
        Please use full paths!
"

if [ "$1" == "-h" ] || [ "$1" == "" ] || [ "$#" != 6 ]; then
        echo -e $USAGE
        exit $STATE_UNKNOWN
fi

while getopts n:l:t: option
do
        case "${option}"
                in
                n) nagiosLog=${OPTARG};;
                l) lastRun=${OPTARG};;
                t) timeNotStartedTreshold=${OPTARG};;
        esac
done

if [ ! -f $lastRun ] && [ ! -f $nagiosLog ]; then
        echo "Last run file $lastRun and Nagios inf $nagiosLog not found! This may be first run of $zimbraScriptName or sometning is wrong"
        exit $STATE_UNKNOWN
fi

if [ -f $nagiosLog ]; then
        pidNumber=$(sed '1q;d' $nagiosLog)
        if [ -f /proc/$pidNumber/status ]; then
                echo "OK $scriptName is running | running=1"
                exit $STATE_OK
        else
                echo "WARNING $scriptName is NOT running and INF $nagiosLog exists | running=0"
                exit $STATE_WARNING
        fi
fi

if [ -f $lastRun ] && [ ! -f $nagiosLog ]; then
        lastRunTS=$(sed '1q;d' $lastRun)
        if [ $(($lastRunTS + $timeNotStartedTreshold)) -lt $tsNow ]; then
                echo "WARNING Last successful run started on $(date -d @$lastRunTS) | running=0"
                exit $STATE_WARNING
        else
                echo "OK backup finished without errors. Last successful run started on $(date -d @$lastRunTS) | running=0"
                exit $STATE_OK
        fi
fi
