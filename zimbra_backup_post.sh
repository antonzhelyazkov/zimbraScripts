#!/usr/bin/env bash

########### VARS ###########
source /usr/local/zimbraScripts/zimbra_backup_src.sh
########### VARS ###########

echo "$(print_time) INFO POST started" >> $LOG_FILE

if [ $DST_DIR == "/" ] || [ -z $DST_DIR ]
then
    echo "$(print_time) INFO POST directory is equal to / exit" >> $LOG_FILE
    exit 1
else
    echo "$(print_time) INFO POST directory exists $DST_DIR" >> $LOG_FILE   
fi

if [ -f "$PID_FILE" ] && [ -d $DST_DIR ]
then
    PID_CMD=$(ps -p `cat /var/run/zimbra_backup.pid` -o comm=)
    if [ ! -z $PID_CMD ]
    then
        if [ $PID_CMD == "sh" ]
        then
            echo "$(print_time) backup process is running PID $PID_CMD" >> $LOG_FILE
            exit 1
        else
            echo "$(print_time) PID $PID_CMD process not equal to sh" >> $LOG_FILE
        fi
    else
        echo "$(print_time) no CMD responding to PID $PID_CMD" >> $LOG_FILE
    fi
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
