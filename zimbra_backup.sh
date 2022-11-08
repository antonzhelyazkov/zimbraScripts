#!/usr/bin/env bash

########### VARS ###########
source /usr/local/zimbraScripts/zimbra_backup_src.sh
ERROR_COUNT=0
########### VARS ###########

if [ -f "$PID_FILE" ]
then
    echo "$(print_time) ERROR pid file $PID_FILE"
    echo "$(print_time) ERROR pid file $PID_FILE" >> $LOG_FILE
    exit 1
else
    echo $$ > $PID_FILE
fi

if [[ "$(id -u)" -eq 0 ]]
then
    echo "$(print_time) INFO RUN You are running the script as root" >> $LOG_FILE
else
    echo "$(print_time) ERROR You must start script as root EXIT" >> $LOG_FILE
    exit 1
fi

if [ -d $DST_DIR ]
then
    echo "$(print_time) ERROR directory exists $DST_DIR" >> $LOG_FILE
    exit 1
else 
    echo "$(print_time) INFO RUN directory missing $DST_DIR" >> $LOG_FILE
    if mkdir -p $DST_DIR
    then
        echo "$(print_time) INFO directory created $DST_DIR" >> $LOG_FILE
    else
        echo "$(print_time) ERROR directory could not be created $DST_DIR" >> $LOG_FILE
        exit 1
    fi
fi

chown zimbra.zimbra $DST_DIR
if sudo -u zimbra /opt/zimbra/bin/zmprov gad > $DST_DIR/domains.txt
then
    echo "$(print_time) INFO RUN dump domains" >> $LOG_FILE
else
    echo "$(print_time) ERROR in dump domains" >> $LOG_FILE
    exit 1
fi

if sudo -u zimbra /opt/zimbra/bin/zmprov gaaa > $DST_DIR/admins.txt
then
    echo "$(print_time) INFO RUN dump admins" >> $LOG_FILE
else
    echo "$(print_time) ERROR in dump admins" >> $LOG_FILE
    exit 1
fi

if sudo -u zimbra /opt/zimbra/bin/zmprov -l gaa > $DST_DIR/emails.txt
then
    echo "$(print_time) INFO RUN dump emails" >> $LOG_FILE
else
    echo "$(print_time) ERROR in dump emails" >> $LOG_FILE
fi

if sudo -u zimbra /opt/zimbra/bin/zmprov gadl > $DST_DIR/distributinlist.txt
then
    echo "$(print_time) INFO RUN dump distributinlist" >> $LOG_FILE
else
    echo "$(print_time) ERROR in dump distributinlist" >> $LOG_FILE
fi

if sudo -u zimbra mkdir -p $DST_DIR/distributinlist_members
then
    echo "$(print_time) INFO RUN mkdir $DST_DIR/distributinlist_members" >> $LOG_FILE
else
    echo "$(print_time) ERROR in mkdir $DST_DIR/distributinlist_members" >> $LOG_FILE
    exit 1
fi

for i in `cat $DST_DIR/distributinlist.txt`
do
    if sudo -u zimbra /opt/zimbra/bin/zmprov gdlm $i > $DST_DIR/distributinlist_members/$i.txt ;echo "$i"
    then
        echo "$(print_time) INFO RUN dump distribution list $i" >> $LOG_FILE
    else
        echo "$(print_time) ERROR in dump distribution list $i" >> $LOG_FILE
    fi
done

if sudo -u zimbra mkdir -p $DST_DIR/userpass
then
    echo "$(print_time) INFO RUN mkdir $DST_DIR/userpass" >> $LOG_FILE
else
    echo "$(print_time) ERROR in mkdir $DST_DIR/userpass" >> $LOG_FILE
    exit 1
fi

for i in `cat $DST_DIR/emails.txt`
do 
    
    if sudo -u zimbra /opt/zimbra/bin/zmprov -l ga $i userPassword | grep userPassword: | awk '{ print $2}' > $DST_DIR/userpass/$i.shadow
    then
        echo "$(print_time) INFO RUN userpass $i" >> $LOG_FILE
    else
        echo "$(print_time) ERROR userpass $i" >> $LOG_FILE
    fi
done

if sudo -u zimbra mkdir -p $DST_DIR/userdata
then
    echo "$(print_time) INFO RUN mkdir $DST_DIR/userdata" >> $LOG_FILE
else
    echo "$(print_time) ERROR in mkdir $DST_DIR/userdata" >> $LOG_FILE
    exit 1
fi

for i in `cat $DST_DIR/emails.txt`
do 
    if sudo -u zimbra /opt/zimbra/bin/zmprov ga $i  | grep -i Name: > $DST_DIR/userdata/$i.txt
    then
        echo "$(print_time) INFO RUN userdata $i" >> $LOG_FILE
    else
        echo "$(print_time) ERROR userdata $i" >> $LOG_FILE
    fi
done

if sudo -u zimbra mkdir -p $DST_DIR/usermail
then
    echo "$(print_time) INFO RUN mkdir $DST_DIR/usermail" >> $LOG_FILE
else
    echo "$(print_time) ERROR in mkdir $DST_DIR/usermail" >> $LOG_FILE
    exit 1
fi

for email in `cat $DST_DIR/emails.txt`
do  
    if sudo -u zimbra /opt/zimbra/bin/zmmailbox -z -m $email getRestURL '/?fmt=tgz' > $DST_DIR/usermail/$email.tgz
    then
        echo "$(print_time) INFO RUN dump email $email" >> $LOG_FILE
    else
        echo "$(print_time) ERROR dump email $email" >> $LOG_FILE
    fi
done

if sudo -u zimbra mkdir -p $DST_DIR/alias
then
    echo "$(print_time) INFO RUN mkdir $DST_DIR/alias" >> $LOG_FILE
else
    echo "$(print_time) ERROR in mkdir $DST_DIR/alias" >> $LOG_FILE
fi

for i in `cat $DST_DIR/emails.txt`
do 
    if sudo -u zimbra /opt/zimbra/bin/zmprov ga  $i | grep zimbraMailAlias |awk '{print $2}' > $DST_DIR/alias/$i.txt
    then
        echo "$(print_time) INFO RUN dump alias $i" >> $LOG_FILE
    else
        echo "$(print_time) ERROR in dump alias $i" >> $LOG_FILE
    fi
    if [ ! -s $DST_DIR/alias/$i.txt ]
    then
        rm -f $DST_DIR/alias/$i.txt
    fi
done

# for i in `cat /backups/zmigrate/domains.txt `; do  zmprov cd $i zimbraAuthMech zimbra ;echo $i ;done

# USERPASS="/backups/zmigrate/userpass"
# USERDDATA="/backups/zmigrate/userdata"
# USERS="/backups/zmigrate/emails.txt"
# for i in `cat $USERS`
# do
# givenName=$(grep givenName: $USERDDATA/$i.txt | cut -d ":" -f2)
# displayName=$(grep displayName: $USERDDATA/$i.txt | cut -d ":" -f2)
# shadowpass=$(cat $USERPASS/$i.shadow)
# tmpPass="CHANGEme"
# zmprov ca $i CHANGEme cn "$givenName" displayName "$displayName" givenName "$givenName" 
# zmprov ma $i userPassword "$shadowpass"
# done

# for i in `cat /backups/zmigrate/emails.txt`; do zmmailbox -z -m $i postRestURL "/?fmt=tgz&resolve=skip" /backups/zmigrate/$i.tgz ;  echo "$i -- finished "; done
# for i in `cat distributinlist.txt`; do zmprov cdl $i ; echo "$i -- done " ; done

# for i in `cat distributinlist.txt`
# do
# 	for j in `grep -v '#' distributinlist_members/$i.txt |grep '@'` 
# 	do
# 	zmprov adlm $i $j
# 	echo " $j member has been added to list $i"
# 	done
# done

# for i in `cat /backups/zmigrate/emails.txt`
# do
# 	if [ -f "alias/$i.txt" ]; then
# 	for j in `grep '@' /backups/zmigrate/alias/$i.txt`
# 	do
# 	zmprov aaa $i $j
# 	echo "$i HAS ALIAS $j --- Restored"
# 	done
# 	fi
# done

if [[ $ERROR_COUNT -eq 0 ]]
then
    if rm -f $PID_FILE
    then
        echo "$(print_time) INFO OK Finished" >> $LOG_FILE
    fi
else
    echo "$(print_time) ERROR Script finished with errors" >> $LOG_FILE
fi
