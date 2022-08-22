#!/usr/bin/env bash

########### VARS ###########
source /opt/zimbraScripts/zimbra_backup_src.sh
########### VARS ###########

print_time(){
    echo $(date +"%Y-%m-%d %H:%M:%S")
}

echo "$(print_time) INFO POST started" >> $LOG_FILE

if [ $DST_DIR == "/" ]
then
    echo "$(print_time) INFO POST directory is equal to / exit" >> $LOG_FILE
    exit 1
else
    echo "$(print_time) INFO POST directory is $DST_DIR" >> $LOG_FILE   
fi

if [ -f "$PID_FILE" ] && [ -d $DST_DIR ]
then
    if rm -f $PID_FILE
    then
        echo "$(print_time) INFO POST rm $PID_FILE" >> $LOG_FILE
    else
        echo "$(print_time) ERROR POST rm $PID_FILE" >> $LOG_FILE
        exit 1
    fi

    if rm -rf $DST_DIR
    then
        echo "$(print_time) INFO POST rm $DST_DIR" >> $LOG_FILE
    else
        echo "$(print_time) ERROR POST rm $DST_DIR" >> $LOG_FILE
    fi
elif [ ! -d $DST_DIR ]
then
    echo "$(print_time) ERROR POST directory does not $DST_DIR" >> $LOG_FILE
    exit 1
elif [ ! -f "$PID_FILE" ]
then
    echo "$(print_time) ERROR POST pid file not found $PID_FILE" >> $LOG_FILE
    exit 1
else
    echo "$(print_time) ERROR POST IN $PID_FILE $DST_DIR" >> $LOG_FILE
    exit 1
fi