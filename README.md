# zimbraScripts

zimbraBackup.sh is script for email archive

nrpe configuration

command[check_zimbra_backup]=/usr/local/bin/nagiosConnect.sh -n /var/log/zimbraBackup.nagios -l /var/log/zimbraBackup.last -t 86400
