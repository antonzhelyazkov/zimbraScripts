#!/bin/sh
#
#       1. Script must be started on backup (remote server)
#       2. Script must be executed by user. ROOT could not start script
#       3. You must create public key and copy to root on remote machite
#       4. All backups are stored in $HOME/backups
#       5. Create NFS Export for each client. /etc/exports
#
#
#
#

USAGE="Usage: $(basename $0) [-h] [-i installation package] [-H zimbra host] [-b backup home] [-N nfs host address] [-s snapshot size]\n
        -i [FILE] Path to installation package on remote host - /root/zcs-8.7.11_GA_1854.RHEL7_64.20170531151956.tgz\n
        -H [IP] IP address of remote Zimbra host\n
        -b [DIR] full path to local backup dir. It must be home directory of user who run this script\n
        -N [IP] NFS Host Address\n
        -s [SIZE] Size in GB\n
        Please use full paths!
"

if [ "$1" == "-h" ] || [ "$1" == "" ] || [ "$#" != 10 ]; then
        echo -e $USAGE
        exit $STATE_UNKNOWN
fi

while getopts i:H:b:N:s: option
do
        case "${option}"
                in
                i) remoteZimbraInstallationArchive=${OPTARG};;
                H) remoteHost=${OPTARG};;
                b) backupHome=${OPTARG};;
                N) nfsHost=${OPTARG};;
                s) snapshotSize=${OPTARG};;
        esac
done

backupHome=$(echo $backupHome | sed 's:/*$::')

#########################

verbose=1

remoteSnapshotName="optSnap"
remoteUser="root"
remotePort=22
remoteTimeout=4
remoteSnapshotSize=$snapshotSize."G"
remoteMountPount="/mnt/snap"
remoteMountNFS="/mnt/backupNFS"
remoteZimbraUser="zimbra"
remotePIGZBin="/usr/bin/pigz"

dateTs=$(date +%s)
nfsPort111="111"
nfsPort2049="2049"
nfsExports="/etc/exports"
zimbraBin="/etc/init.d/zimbra"
zmcontrolBin="/opt/zimbra/bin/zmcontrol"
identityFile="$HOME/.ssh/id_rsa"
logDir="$backupHome/log"
nagiosLog="$logDir/zimbraSnapshot.inf"
scriptLog="$logDir/zimbraSnapshot.log"
lastRun="$logDir/zimbraSnapshot.last"
currentDate=$(date +%Y%m%d%H%M%S)
currentBackup="$backupHome/backups"
currentBackupDir="$currentBackup/$currentDate"
userInfFile="$currentBackupDir/user.inf"
keepBackupDays=5
backupDays=$(date +%Y%m%d%H%M%S -d "$keepBackupDays day ago")

sshBin="/usr/bin/ssh"
timeoutBin="/bin/timeout"

########################

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

echo `date` $logMessage >> $scriptLog

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

function checkZimbraStatus() {

running=0
stopped=0
zimbraStatus=( $($sshBin -i $identityFile $remoteUser@$remoteHost "$zimbraBin status" 2>&1) )

for (( i=0; i<${#zimbraStatus[@]}; i++ )); do
        if [ ${zimbraStatus[i]} = "Running" ]; then
                ((running++))
        fi
        if [ ${zimbraStatus[i]} = "Stopped" ]; then
                ((stopped++))
        fi
done

if [ $running -gt 16 ] && [ $stopped -eq 0 ]; then
        echo 0
fi

if [ $running -gt 2 ] && [ $stopped -gt 2 ]; then
        echo 2
fi

if [ $running -lt 2 ] && [ $stopped -gt 15 ]; then
        echo 1
fi

}

function umountAndRemove() {

if [ "$#" != 3 ]; then
        logPrint "wrong umountAndRemove function usage"
fi

if [ -z $1 ]; then
        umountNFS=0
else
        if [[  $1 =~ ^[0-1]{1}$ ]]; then
                umountNFS=$1
        else
                umountNFS=0
        fi
fi

if [ -z $2 ]; then
        umountSnapshot=0
else
        if [[  $2 =~ ^[0-1]{1}$ ]]; then
                umountSnapshot=$2
        else
                umountSnapshot=0
        fi
fi

if [ -z $3 ]; then
        removeSnapshot=0
else
        if [[  $3 =~ ^[0-1]{1}$ ]]; then
                removeSnapshot=$3
        else
                removeSnapshot=0
        fi
fi

if [ $umountNFS -eq 1 ]; then
        $sshBin -i $identityFile $remoteUser@$remoteHost "umount $remoteMountNFS"
        remoteUmountNFSExitStatus=$?
        if [ $remoteUmountNFSExitStatus -ne 0 ]; then
                logPrint "ERROR could not umount remote NFS $remoteMountNFS" 1 1
        else
                logPrint "OK umount remote NFS $remoteMountNFS" 0 0
        fi
fi

if [ $umountSnapshot -eq 1 ]; then
        $sshBin -i $identityFile $remoteUser@$remoteHost "umount $remoteMountPount"
        remoteUmountSnapshotExitStatus=$?
        if [ $remoteUmountSnapshotExitStatus -ne 0 ]; then
                logPrint "ERROR could not umount remote snapshot $remoteMountPount" 1 1
        else
                logPrint "OK umount remote snapshot $remoteMountPount" 0 0
        fi
fi

if [ $removeSnapshot -eq 1 ]; then
        $sshBin -i $identityFile $remoteUser@$remoteHost "lvremove -f $remoteSnapshot"
        remoteRemoveSnapshotExitStatus=$?
        if [ $remoteRemoveSnapshotExitStatus -ne 0 ]; then
                logPrint "ERROR could not remove remote snapshot $remoteSnapshot" 1 1
        else
                logPrint "OK remove remote snapshot $remoteSnapshot" 0 0
        fi
fi

}

#######################

logPrint START 0 0

if [ -f $nagiosLog ]; then
        logPrint "file $nagiosLog exists EXIT!" 1 1
else
        echo $$ > $nagiosLog
fi

if [[ $EUID -eq 0 ]]; then
        logPrint "This script must NOT be run as root current $EUID" 1 1
else
        logPrint "Current UID is $EUID" 0 0
fi

if [ ! -d ${backupHome} ]; then
        logPrint "Directory ${backupHome} is does NOT exist" 0 1
else
        logPrint "Directory ${backupHome} exists" 0 0
fi

if [ ! -f ${identityFile} ]; then
        logPrint "Identity File ${identityFile} not found" 0 1
else
        logPrint "Identity File ${identityFile}" 0 0
fi

if [ ! -d ${currentBackup} ]; then
        mkdir ${currentBackup}
        if [ ! -d ${currentBackup} ]; then
                logPrint "Directory ${currentBackup} is does NOT exist and could not create it. Try mkdir ${currentBackup}" 0 1
        fi
fi

test -w $currentBackup
writeTest=$?
if [ $writeTest -ne 0 ] ; then
        logPrint "Directory ${currentBackup} is does NOT writtable ${currentBackup}" 1 1
else
        logPrint "Directory ${currentBackup} exists and is writtable" 0 0
fi

mkdir $currentBackupDir

if [ ! -d ${logDir} ]; then
        mkdir ${logDir}
        if [ ! -d ${logDir} ]; then
                logPrint "Directory ${logDir} is does NOT exist and could not create it. Try mkdir ${logDir}" 0 1
        fi
fi

test -w $logDir
writeTestLog=$?
if [ $writeTestLog -ne 0 ] ; then
        logPrint "Directory ${logDir} is does NOT writtable" 1 1
else
        logPrint "Directory ${logDir} exists and is writtable" 0 0
fi

$timeoutBin $remoteTimeout bash -c "</dev/tcp/$remoteHost/$remotePort"
connectionStatus=$?
if [ $connectionStatus -ne 0 ]; then
        logPrint "ERROR Connection problem to host $remoteHost port $remotePort" 1 1
else
        logPrint "Connection success to host $remoteHost port $remotePort" 0 0
fi

cat $nfsExports | grep -qw $currentBackup
checkNFSShare=$?
if [ $checkNFSShare -ne 0 ]; then
        logPrint "ERROR Incorrect nfs share in $nfsExports. $currentBackup not found" 1 1
fi

remoteVolumeGroup=$($sshBin -i $identityFile $remoteUser@$remoteHost "pvs --noheadings -o vg_name | sed \"s/ //g\"")
volumeGroupNameStatus=$?
if [ $volumeGroupNameStatus -ne 0 ]; then
        logPrint "ERROR Could not get remote Volume Group Name" 1 1
else
        logPrint "remote Volume Group Name $remoteVolumeGroup" 0 0
fi

#######################

remoteZimbraLVM="/dev/mapper/$remoteVolumeGroup-opt"
remoteSnapshot="/dev/$remoteVolumeGroup/$remoteSnapshotName"

######################

if [[ $snapshotSize =~ ^[0-9]+$ ]]; then
        logPrint "Correct Snapshot Size $snapshotSize" 0 0
else
        logPrint "ERROR Incorrect Snapshot Size $snapshotSize" 1 1
fi

checkRemoteFreeSpace=$($sshBin -i $identityFile $remoteUser@$remoteHost "pvs --noheadings -o pv_free | sed \"s/ //g\"")
measureString="${checkRemoteFreeSpace: -1}"
sizeValue="${checkRemoteFreeSpace:: -1}"

if [[ $measureString =~ ^g$ ]]; then
        if [ $snapshotSize -gt ${sizeValue%.*} ];then
                logPrint "ERROR Incorrect snapshot size. It must be less than $sizeValue GB" 1 1
        else
                logPrint "Snapshot size seems correct. $snapshotSize GB snapshot could be created in $sizeValue GB free space" 0 0
        fi
elif [[ $measureString =~ ^t$ ]]; then
        sizeValueInGB=$((${sizeValue%.*} * 1000))
        echo $sizeValueInGB
        if [ $snapshotSize -gt $sizeValueInGB ];then
                logPrint "ERROR Incorrect snapshot size. It must be less than $sizeValue GB" 1 1
        else
                logPrint "Snapshot size seems correct. $snapshotSize GB snapshot could be created in $sizeValue GB free space" 0 0
        fi
else
        logPrint "ERROR Something is wrong with remote free space in volume group" 1 1
fi

$sshBin -i $identityFile $remoteUser@$remoteHost "df | grep -qw $remoteZimbraLVM"
checkMountZimbra=$?
if [ $checkMountZimbra -eq 0 ]; then
        logPrint "remote partition $remoteZimbraLVM is mounted" 0 0
else
        logPrint "remote partition $remoteZimbraLVM is NOT mounted" 1 1
fi

zimbraUID=( $($sshBin -i $identityFile $remoteUser@$remoteHost "id -u $remoteZimbraUser") )
zimbraGID=( $($sshBin -i $identityFile $remoteUser@$remoteHost "id -g $remoteZimbraUser") )
remoteHostname=( $($sshBin -i $identityFile $remoteUser@$remoteHost "hostname") )

if ! [[ $zimbraUID =~ ^[0-9]+$ ]]; then
        logPrint "$remoteZimbraUser user daoes not exist on $remoteHost" 1 1
fi

if ! [[ $zimbraGID =~ ^[0-9]+$ ]]; then
        logPrint "$remoteZimbraUser group daoes not exist on $remoteHost" 1 1
fi

echo "$remoteZimbraUser UID $zimbraUID" >> $userInfFile
echo "$remoteZimbraUser GID $zimbraGID" >> $userInfFile
echo "$remoteHostname" >> $userInfFile

$sshBin -i $identityFile $remoteUser@$remoteHost "test -d $remoteMountPount"
remoteMountPointCheck=$?
if [ $remoteMountPointCheck -ne 0 ]; then
        $sshBin -i $identityFile $remoteUser@$remoteHost "mkdir -p $remoteMountPount"
        remoteMountPointMkdir=$?
        if [ $remoteMountPointMkdir -ne 0 ]; then
                logPrint "ERROR could not create remote directory $remoteMountPount" 1 1
        fi
fi

$sshBin -i $identityFile $remoteUser@$remoteHost "test -d $remoteMountNFS"
remoteMountNFSCheck=$?
if [ $remoteMountNFSCheck -ne 0 ]; then
        $sshBin -i $identityFile $remoteUser@$remoteHost "mkdir -p $remoteMountNFS"
        remoteMountNFSMkdir=$?
        if [ $remoteMountNFSMkdir -ne 0 ]; then
                logPrint "ERROR could not create remote directory $remoteMountNFS" 1 1
        fi
fi

$sshBin -i $identityFile $remoteUser@$remoteHost "test -f $remoteZimbraInstallationArchive"
checkInstallationPacket=$?

if [ $checkInstallationPacket -ne 0 ]; then
        logPrint "ERROR Installation packet not found $remoteZimbraInstallationArchive" 1 0
else
        checkZimbraVersion=$($sshBin -i $identityFile $remoteUser@$remoteHost "sudo -u zimbra $zmcontrolBin -v | cut -d' ' -f2 | cut -d'_' -f1")
        echo $remoteZimbraInstallationArchive | cut -d'-' -f2 | cut -d'_' -f1 | grep -qw $checkZimbraVersion
        checkIfVersionIsValid=$?
        if [ $checkIfVersionIsValid -eq 0 ]; then
                logPrint "OK packet version in $remoteZimbraInstallationArchive and running zimbra version $checkZimbraVersion seems equal" 0 0
                scp -q -i $identityFile $remoteUser@$remoteHost:$remoteZimbraInstallationArchive $currentBackupDir
        else
                logPrint "ERROR packet version in $remoteZimbraInstallationArchive is diferent than running zimbra version $checkZimbraVersion" 1 1
        fi
fi

$sshBin -i $identityFile $remoteUser@$remoteHost "test -f $remotePIGZBin"
checkRemotePIGZBin=$?

if [ $checkRemotePIGZBin -ne 0 ]; then
        logPrint "ERROR pigz not found on remote server" 1 1
fi

$timeoutBin $remoteTimeout bash -c "</dev/tcp/$nfsHost/$nfsPort111"
connectionStatusPort111=$?
if [ $connectionStatusPort111 -ne 0 ]; then
        logPrint "ERROR Connection problem to host $nfsHost port $nfsPort111" 1 1
else
        logPrint "Connection success to host $nfsHost port $nfsPort111" 0 0
fi

$timeoutBin $remoteTimeout bash -c "</dev/tcp/$nfsHost/$nfsPort2049"
connectionStatusPort2049=$?
if [ $connectionStatusPort2049 -ne 0 ]; then
        logPrint "ERROR Connection problem to host $nfsHost port $nfsPort2049" 1 1
else
        logPrint "Connection success to host $nfsHost port $nfsPort2049" 0 0
fi

$sshBin -i $identityFile $remoteUser@$remoteHost "mount $nfsHost:$currentBackup $remoteMountNFS"
remoteMountNFSExitStatus=$?
if [ $remoteMountNFSExitStatus -ne 0 ]; then
        logPrint "ERROR could not mount remote NFS to directory $remoteMountNFS" 1 1
else
        logPrint "OK successful mount $nfsHost:$currentBackup $remoteMountNFS" 0 0
fi

####### HouseKeep #######

backupDirs=$(ls $currentBackup)

for directory in $backupDirs ; do
        if [[ $directory =~ ^[0-9]{14}$ ]]; then
                if [ $directory -lt $backupDays ]; then
                        removeDir=$currentBackup/$directory
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

####### HouseKeep #######


checkZimbraStatusResult=$(checkZimbraStatus)
if [ $checkZimbraStatusResult -eq 0 ]; then
        logPrint "Zimbra is running" 0 0
        logPrint "Send STOP command to zimbra" 0 0
        $sshBin -i $identityFile $remoteUser@$remoteHost "$zimbraBin stop" 2>&1
        sleep 3
else
        logPrint "ERROR Zimbra at $remoteHost seemed STOPPED. Something is wrong" 1 1
fi

checkZimbraStopped=$(checkZimbraStatus)
if [ $checkZimbraStopped -ne 1 ]; then
        logPrint "Zimbra NOT stopped something went wrong" 1 1
else
        logPrint "Zimbra is stopped" 0 0
        logPrint "create snapshot" 0 0
        $sshBin -i $identityFile $remoteUser@$remoteHost "lvcreate -L $remoteSnapshotSize -s -n $remoteSnapshotName $remoteZimbraLVM"
        remoteSnapshotCreationExitCode=$?
        if [ $remoteSnapshotCreationExitCode -ne 0 ]; then
                umountAndRemove 1 0 0
                logPrint "ERROR remote snapshot failed" 1 1
        else
                logPrint "OK snapshot created" 0 0
        fi

        logPrint "Starting Zimbra" 0 0
        $sshBin -i $identityFile $remoteUser@$remoteHost "$zimbraBin start" 2>&1
        checkZimbraStatus2=$(checkZimbraStatus)
        if [ $checkZimbraStatus2 -ne 0 ]; then
                umountAndRemove 1 0 1
                logPrint "ERROR Zimbra could not start" 1 1
        else
                logPrint "Zimbra Started" 0 0
        fi
        sleep 5

        $sshBin -i $identityFile $remoteUser@$remoteHost "lvscan | grep -qw $remoteSnapshot"
        remoteSnapshotExit=$?
        if [ $remoteSnapshotExit -ne 0 ]; then
                umountAndRemove 1 0 0
                logPrint "ERROR remote snapshot does not exist $remoteSnapshot" 1 1
        fi

        $sshBin -i $identityFile $remoteUser@$remoteHost "mount -o nouuid,ro $remoteSnapshot $remoteMountPount"
        remoteMountSnapshotExitStatus=$?
        if [ $remoteMountSnapshotExitStatus -ne 0 ]; then
                umountAndRemove 1 0 1
                logPrint "ERROR could not mount remote snapshot to directory $remoteMountPount" 1 1
        else
                logPrint "OK successful mount $remoteSnapshot $remoteMountPount" 0 0
        fi

        $sshBin -i $identityFile $remoteUser@$remoteHost "test -d $remoteMountPount/zimbra/"
        remoteMountZimbraCheck=$?
        if [ $remoteMountZimbraCheck -ne 0 ]; then
                umountAndRemove 1 1 1
                logPrint "ERROR something is wrong. Directory $remoteMountPount/zimbra/ is missing" 1 1
        fi

        logPrint "Start archiving" 0 0
        $sshBin -i $identityFile $remoteUser@$remoteHost "tar -c --use-compress-program=pigz -f $remoteMountNFS/$currentDate/zimbra.tar.gz $remoteMountPount/zimbra/"
        remoteTarExitStatus=$?
        if [ $remoteTarExitStatus -eq 0 ]; then
                logPrint "OK successful archive in $currentDate/zimbra.tar.gz" 0 0
        else
                umountAndRemove 1 1 1
                logPrint "ERROR archive failed in $currentDate/zimbra.tar.gz" 1 1
        fi
        umountAndRemove 1 1 1
fi

if grep -Fq "ERROR" $nagiosLog ; then
        logPrint "ERRORS are found. Must not remove $nagiosLog" 0 0
else
        rm -f $nagiosLog
        logPrint "FINISH" 0 0
fi
echo $dateTs > $lastRun
