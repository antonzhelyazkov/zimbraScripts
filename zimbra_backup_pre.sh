#!/usr/bin/env bash

########### VARS ###########
source /usr/local/zimbraScripts/zimbra_backup_src.sh
########### VARS ###########

echo "$(print_time) INFO PRE started" `id` >> $LOG_FILE

if [ -f "$PID_FILE" ]
then
    echo "$(print_time) ERROR PRE pid file $PID_FILE exists" >> $LOG_FILE
    exit 1
elif [ -d $DST_DIR ]
then
    echo $$ > $PID_FILE
else
    echo "$(print_time) ERROR PRE NO pid file $PID_FILE NO dst dir $DST_DIR" >> $LOG_FILE
    exit 1
fi
