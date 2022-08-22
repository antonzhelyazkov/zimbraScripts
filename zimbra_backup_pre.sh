#!/usr/bin/env bash

########### VARS ###########
source /opt/zimbraScripts/zimbra_backup_src.sh
########### VARS ###########

print_time(){
    echo $(date +"%Y-%m-%d %H:%M:%S")
}

echo "$(print_time) INFO PRE started" `id` >> $LOG_FILE

if [ -f "$PID_FILE" ]
then
    echo "$(print_time) ERROR PRE pid file $PID_FILE" >> $LOG_FILE
    exit 1
else
    echo $$ > $PID_FILE
fi

if [ -d $TMP_DIR ]
then
    echo "$(print_time) INFO RUN directory exists $TMP_DIR"
    echo "$(print_time) INFO RUN directory exists $TMP_DIR" >> $LOG_FILE
    exit 1
fi

if [ ! -d $DST_DIR ]
then
    echo "$(print_time) INFO RUN directory does not exist $DST_DIR"
    echo "$(print_time) INFO RUN directory does not exist $DST_DIR" >> $LOG_FILE
    exit 1
fi