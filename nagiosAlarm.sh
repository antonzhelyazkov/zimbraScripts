#!/bin/bash

tsNow=$(date +%s)

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

########################################

USAGE="Usage: $(basename $0) [-h] [-n nagios log] [-t time interval]\n
        -n [FILE] Path to nagios log - zimbraSnapshot.log.\n
        -t [INT] Time interval between executions.\n
        Please use full paths!
"

if [ "$1" == "-h" ] || [ "$1" == "" ] || [ "$#" != 4 ]; then
        echo -e $USAGE
        exit $STATE_UNKNOWN
fi

while getopts n:t: option
do
        case "${option}"
                in
                n) nagiosLog=${OPTARG};;
                t) timeNotStartedTreshold=${OPTARG};;
        esac
done

if [ ! -f $nagiosLog ]
then
    echo "WARNING file not found $nagiosLog"
    exit $STATE_CRITICAL
fi

log_last=$(tail -n 1 $nagiosLog)

log_date=$(echo $log_last | cut -d " " -f 1,2)
log_status=$(echo $log_last | cut -d " " -f 3)
log_action=$(echo $log_last | cut -d " " -f 4)
log_timestamp=$(date -d "$log_date" +%s)
date_ref=$(date -d "-$timeNotStartedTreshold hour" +%s)

if [[ $log_timestamp -lt $date_ref ]]
then
    echo "WARNING last script execution was before $log_date"
    exit $STATE_WARNING
fi

if [ $log_status = 'ERROR' ]
then
    echo "WARNING backup script exitetd with ERRORS"
    exit $STATE_WARNING
fi

if [ $log_action = 'RUN' ] && [[ $log_timestamp -gt $date_ref ]]
then
    echo "OK backup script is running"
    exit $STATE_OK
fi

echo "OK backup script finished correctly"
exit $STATE_OK
    