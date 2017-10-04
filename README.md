# zimbraScripts

  zimbraBackup.sh is script for email archive
  nrpe configuration
  command[check_zimbra_backup]=/usr/local/bin/nagiosConnect.sh -n /var/log/zimbraBackup.nagios -l /var/log/zimbraBackup.last -t 86400

# zimbraSessions
Script counts Zimbra IMAP sessions. Script must be started as zimbra user

  command[check_zimbra_imap_sessions]=sudo -u zimbra /usr/lib64/nagios/plugins/zimbraImapSessions.pl
