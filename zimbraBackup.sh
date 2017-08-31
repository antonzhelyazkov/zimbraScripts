#!/bin/sh

ftpHost=10.10.10.10
ftpUser=qwe
ftpPass=qweqwe

verbose=1

dateTs=$(date +%s)
ownScriptName=$(basename "$0" | sed -e 's/.sh$//g')
hostname=$(hostname)
scriptLog="/var/log/$ownScriptName.log"
nagiosLog="/var/log/$ownScriptName.nagios"
lastRun="/var/log/$ownScriptName.last"

keepLocalCopy=1
keepLocalBackupDays=1
localBackupDays=$(date +%Y%m%d%H%M%S -d "$keepLocalBackupDays day ago")

keepRemoteCopy=1
keepRemoteBackupDays=0
remoteBackupDays=$(date +%Y%m%d%H%M%S -d "$keepRemoteBackupDays day ago")

zimbraUser="zimbra"
zimbraZmprov="/opt/zimbra/bin/zmprov"
zimbraZmmailbox="/opt/zimbra/bin/zmmailbox"

zmprovCommand="/bin/sudo -u $zimbraUser $zimbraZmprov"
zmmailboxCommand="/bin/sudo -u $zimbraUser $zimbraZmmailbox"
curlBin="/bin/curl"
lftpBin="/bin/lftp"

localBackupDir="/opt/backup"
currentDate=$(date +%Y%m%d%H%M%S)
currentBackupDir="$localBackupDir/$currentDate"
tmpDir="$currentBackupDir/tmp"
distributinlistMembersDir="$currentBackupDir/distributinlistMembers"
userpassDir="$currentBackupDir/userpass"
userdataDir="$currentBackupDir/userdata"
filtersDir="$currentBackupDir/filters"
mailDir="$currentBackupDir/mail"
restoreScriptsDir="$currentBackupDir/restoreScripts"
domainsFile="$currentBackupDir/domains.txt"
adminsFile="$currentBackupDir/admins.txt"
emailsFile="$currentBackupDir/emails.txt"
distributinlistFile="$currentBackupDir/distributinlist.txt"
restoreCreateUsers="$restoreScriptsDir/createUsers.sh"

##############################

function logPrint() {

logMessage=$1

if [ -z $2 ]; then
        nagios=0
else
        if [[  $2 =~ ^[0-1]{1}$ ]]; then
                nagios=$2
        else
                nagios=0
        fi
fi

if [ -z $3 ]; then
        exitCommand=0
else
        if [[  $3 =~ ^[0-1]{1}$ ]]; then
                exitCommand=$3
        else
                exitCommand=0
        fi
fi

echo $(date) $logMessage >> $scriptLog

if [ $verbose -eq 1 ]; then
        echo $logMessage
fi

if [ $nagios -eq 1 ]; then
        echo $logMessage >> $nagiosLog
fi

if [ $exitCommand -eq 1 ]; then
        exit
fi

}

function createDir() {
currentDir=$1

if [ ! -d $currentDir ]; then
        logPrint "Directory $currentDir is does NOT exist" 0 0
        /bin/sudo -u $zimbraUser mkdir $currentDir
        checkMkdirExitStatus=$?
        if [ $checkMkdirExitStatus -ne 0 ]; then
                logPrint "ERROR Could not create $currentDir" 1 1
        else
                logPrint "Directory $currentDir created" 0 0
        fi
else
        logPrint "Directory $currentDir exists" 0 0
        /bin/sudo -u $zimbraUser /bin/test -w $currentDir
        checkWriteToTmpBackupDir=$?
        if [ $checkWriteToTmpBackupDir -ne 0 ]; then
                logPrint "user $zimbraUser could not write to $currentDir" 1 1
        fi
fi

}

##############################

logPrint START 0 0

if [ -f $nagiosLog ]; then
        logPrint "file $nagiosLog exists EXIT!" 1 1
else
        echo $$ > $nagiosLog
fi

if [[ $EUID -ne 0 ]]; then
        logPrint "This script must be run as root. Current user $EUID" 1 1
else
        logPrint "Current UID is $EUID" 0 0
fi

if [ ! -d $localBackupDir ]; then
        logPrint "Directory $localBackupDir is does NOT exist" 0 1
else
        logPrint "Directory $localBackupDir exists" 0 0
fi

id $zimbraUser > /dev/null 2>&1
checkZimbraUser=$?
if [ $checkZimbraUser -ne 0 ]; then
        logPrint "user $zimbraUser does NOT exist" 1 1
fi

/bin/sudo -u $zimbraUser /bin/test -w $localBackupDir
checkWriteToBackupDir=$?
if [ $checkWriteToBackupDir -ne 0 ]; then
        logPrint "user $zimbraUser could not write to $localBackupDir" 1 1
fi

if [ ! -e $zimbraZmprov ]; then
        logPrint "zmprov not found in $zimbraZmprov" 0 1
else
        logPrint "zmprove found $zimbraZmprov" 0 0
fi

if [ ! -e $curlBin ]; then
        logPrint "curl not found in $curlBin" 0 1
else
        logPrint "curl found $curlBin" 0 0
fi

if [ ! -e $lftpBin ]; then
        logPrint "lftp not found in $lftpBin" 0 1
else
        logPrint "lftp found $lftpBin" 0 0
fi

createDir $currentBackupDir
createDir $tmpDir
createDir $distributinlistMembersDir
createDir $userpassDir
createDir $userdataDir
createDir $filtersDir
createDir $mailDir
createDir $restoreScriptsDir

logPrint "create distributinlists file $domainsFile" 0 0
$zmprovCommand gad > $domainsFile
checkStatusGAD=$?
if [ $checkStatusGAD -ne 0 ]; then
        logPrint "ERROR could not execute $zmprovCommand gad > $domainsFile" 1 1
fi

logPrint "create distributinlists file $adminsFile" 0 0
$zmprovCommand gaaa > $adminsFile
checkStatusGAAD=$?
if [ $checkStatusGAAD -ne 0 ]; then
        logPrint "ERROR could not execute $zmprovCommand gaaa > $adminsFile" 1 1
fi

logPrint "create distributinlists file $emailsFile" 0 0
$zmprovCommand -l gaa > $emailsFile
checkStatusGAA=$?
if [ $checkStatusGAA -ne 0 ]; then
        logPrint "ERROR could not execute $zmprovCommand -l gaa > $emailsFile" 1 0
fi

logPrint "create distributinlists file $distributinlistFile" 0 0
$zmprovCommand gadl > $distributinlistFile
checkStatusGADL=$?
if [ $checkStatusGADL -ne 0 ]; then
        logPrint "ERROR could not execute $zmprovCommand gadl > $distributinlistFile" 1 0
fi

while read distributionLists
do
        logPrint "create distributinlist $distributionLists" 0 0
        $zmprovCommand gdlm $distributionLists > $distributinlistMembersDir/$distributionLists.txt
        checkStatusGDLM=$?
        if [ $checkStatusGDLM -ne 0 ]; then
                logPrint "ERROR could not execute $zmprovCommand gdlm > $distributinlistMembersDir/$distributionLists.txt" 1 0
        fi
done < $distributinlistFile

while read email
do
        logPrint "get user password for $email" 0 0
        $zmprovCommand -l ga $email userPassword | grep userPassword: | awk '{ print $2}' > $userpassDir/$email.shadow;
        checkStatusGetUserPass=$?
        if [ $checkStatusGetUserPass -ne 0 ]; then
                logPrint "ERROR could not execute $zmprovCommand -l ga $email userPassword | grep userPassword: | awk \'{ print $2}\' > $userpassDir/$email.shadow" 1 0
        fi
done < $emailsFile

while read email
do
        logPrint "get user data for $email" 0 0
        $zmprovCommand ga $email | grep -i Name: > $userdataDir/$email
        checkStatusGetUserData=$?
        if [ $checkStatusGetUserData -ne 0 ]; then
                logPrint "ERROR could not execute $zmprovCommand ga $email | grep Name: > $userdataDir/$email" 1 0
        fi
done < $emailsFile

while read email
do
        logPrint "get filter for $email" 0 0
        $zmprovCommand ga $email zimbraMailSieveScript > $tmpDir/$email
        sed -i -e "1d" $tmpDir/$email
        sed 's/zimbraMailSieveScript: //g' $tmpDir/$email > $filtersDir/$email
done < $emailsFile

while read email
do
        logPrint "get mail for $email" 0 0
        $zmmailboxCommand -z -m $email getRestURL '/?fmt=tgz' > $mailDir/$email.tgz
        checkGetMail=$?
        if [ $checkGetMail -ne 0 ]; then
                logPrint "ERROR could not execute $zmmailboxCommand -z -m $email getRestURL '/?fmt=tgz' > $mailDir/$email.tgz" 1 0
        fi
done < $emailsFile

############# restore scripts ##############

cat <<END >$restoreCreateUsers
#!/bin/bash

currentDir=\$(dirname \$0)
currentBaseDir=\$(echo "\$currentDir" | sed -r 's/restoreScripts//g')
echo \$currentBaseDir

tmpDir="\$currentBaseDir/tmp"
distributinlistMembersDir="\$currentBaseDir/distributinlistMembers"
userpassDir="\$currentBaseDir/userpass"
userdataDir="\$currentBaseDir/userdata"
filtersDir="\$currentBaseDir/filters"
mailDir="\$currentBaseDir/mail"

zimbraUser="zimbra"
zmprovBin="/opt/zimbra/bin/zmprov"
zmprovCommnand="sudo -u \$zimbraUser \$zmprovBin"

zmmailboxBin="/opt/zimbra/bin/zmmailbox"
zmmailboxCommand="sudo -u \$zimbraUser \$zmmailboxBin"

##############################################

function usage() {

echo "Usage: ./createUser.sh --restore=all"
echo "Usage: ./createUser.sh --restore=test@exampe.com"
echo "--restore         >>>>    restore email or all emails"
exit 1

}

##############################################

for i in "\$@"
do
case \$i in
        --restore=*)
        restore="\${i#*=}"
        shift # past argument=value
        ;;

        *)
        # unknown option
        ;;
esac
done

if [[ -z \$restore ]]; then
        echo "ERROR: restore parameter is not set"
        usage
fi

emailRegex="^[a-z0-9!#\\$%&'*+/=?^_\\\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\\\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\\$"
echo \$restore

if [[ \$restore =~ \$emailRegex ]] || [ \$restore == "all" ]; then
        echo "restore seems valid input \$restore"
else
        echo "restore seems NOT valid input \$restore"
        usage
fi

if [[ \$EUID -ne 0 ]]; then
        echo "This script must be run as root. Current user \$EUID"
        exit
else
        echo "Current UID is \$EUID"
fi

if [ ! -d \$distributinlistMembersDir ] || [ ! -d \$userpassDir ] || [ ! -d \$userdataDir ] || [ ! -d \$filtersDir ] || [ ! -d \$mailDir ]; then
        echo "some directories are missing."
        echo "check \$distributinlistMembersDir"
        echo "check \$userpassDir"
        echo "check \$userdataDir"
        echo "check \$filtersDir"
        echo "check \$mailDir"
        exit
fi

if [ \$restore == "all" ]; then
        users=\$(<\$currentBaseDir/emails.txt)
else
        users=\$restore
        grep -qw \$users \$currentBaseDir/emails.txt
        checkIfEmail=\$?
        if [ \$checkIfEmail -ne 0 ]; then
                echo "email \$users does not exist in archive - \$currentBaseDir/emails.txt"
                exit
        fi
fi

for email in \$users
do
        \$zmprovCommnand -l gaa | grep -q \$email
        checkIfAccountExists=\$?
        if [[ \$checkIfAccountExists -eq 0 ]]; then
                echo "Account \$email alredy exists."
        else
                echo "Account \$email does NOT exit"
                givenName=\$(grep givenName: \$userdataDir/\$email | cut -d ":" -f2 | sed 's/ //g')
                displayName=\$(grep displayName: \$userdataDir/\$email | cut -d ":" -f2 | sed 's/ //g')
                shadowpass=\$(cat \$userpassDir/\$email.shadow)
                echo "create account \$email givenName \$givenName displayName \$displayName"
                tmpPass="CHANGEme"
                \$zmprovCommnand ca \$email CHANGEme cn "\$givenName" displayName "\$displayName" givenName "\$givenName"
                checkCreateUser=\$?
                if [ \$checkCreateUser -eq 0 ]; then
                        echo "user \$email created"
                else
                        echo "ERROR could not create \$zmprovCommnand ca \$email CHANGEme cn \$givenName displayName \$displayName givenName \$givenName"
                fi
                \$zmprovCommnand ma \$email userPassword \$shadowpass
                checkPasswordSet=\$?
                if [ \$checkPasswordSet -eq 0 ]; then
                        echo "password set on \$email"
                else
                        echo "ERROR could not set password for user \$email"
                fi

                echo "restore mail for \$email"
                \$zmmailboxCommand -z -m \$email postRestURL "/?fmt=tgz&resolve=skip" \$mailDir/\$email.tgz
                checkMailRestore=\$?
                if [ \$checkPasswordSet -eq 0 ]; then
                        echo "mail restored \$email"
                else
                        echo "ERROR could not restore mail for \$email"
                fi
        fi
done
END

chmod 755 $restoreCreateUsers

############# restore scripts ##############

if [ $keepRemoteCopy -eq 1 ]; then

        $lftpBin -u $ftpUser:$ftpPass $ftpHost -e "mirror -R $currentBackupDir $hostname/; bye"
        checkUploadExit=$?
        echo $checkUploadExit
        if [ $checkUploadExit -ne 0 ]; then
                logPrint "ERROR in upload" 1 1
        fi

        for currentRemoteDirectory in $($curlBin -s -u $ftpUser:$ftpPass ftp://$ftpHost/$hostname/ -X MLSD | grep 'type=dir' | cut -d';' -f8)
        do
                if [[ $currentRemoteDirectory =~ ^[0-9]{14}$ ]]; then
                        if [ $currentRemoteDirectory -lt $remoteBackupDays ]; then
                                if [ ! -z $currentRemoteDirectory ]; then
                                        logPrint "remove $hostname/$currentRemoteDirectory" 0 0
                                        $lftpBin -u $ftpUser:$ftpPass $ftpHost -e "rm -r $hostname/$currentRemoteDirectory; bye"
                                        checkRemoteRemove=$?
                                        if [ $checkRemoteRemove -ne 0 ]; then
                                                logPrint "ERROR could not remove remote directory $hostname/$currentRemoteDirectory" 1 0
                                        fi
                                fi
                        fi
                fi
        done
fi

####### Local HouseKeep #######

if [ $keepLocalCopy -eq 1 ]; then

        localBackupDirs=$(ls $localBackupDir)

        for directory in $localBackupDirs ; do
                if [[ $directory =~ ^[0-9]{14}$ ]]; then
                        if [ $directory -lt $localBackupDays ]; then
                                removeDir=$localBackupDir/$directory
                                logPrint "check if directory exists $removeDir" 0 0
                                if [ -d $removeDir ] && [ ! -z $directory ] ; then
                                        logPrint "remove $removeDir" 0 0
                                        rm -rf $removeDir
                                        removeDirStatus=$?
                                        logPrint "remove status $removeDirStatus" 0 0
                                        if [ $removeDirStatus -ne 0 ]; then
                                                logPrint "ERROR could not remove directory $removeDir" 1 1
                                        fi
                                else
                                        logPrint "ERROR directory $removeDir does not exist. Someting went wrong" 1 1
                                fi
                        fi
                fi
        done
else
        rm -rf $localBackupDir/*
fi

####### Local HouseKeep #######

if grep -Fq "ERROR" $nagiosLog ; then
        logPrint "ERRORS are found. Must not remove $nagiosLog" 0 0
else
        rm -f $nagiosLog
        logPrint "FINISH" 0 0
fi
echo $dateTs > $lastRun
