#!/usr/bin/env bash

DST_DIR='/mnt/zimbra_backup'
LOG_FILE='/var/log/zimbra_backup.log'
PID_FILE='/var/run/zimbra_backup.pid'

print_time(){
    echo $(date +"%Y-%m-%d %H:%M:%S")
}