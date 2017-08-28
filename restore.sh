#!/bin/bash

currentDir=$(dirname $0)

currentBaseDir=$(echo "$currentDir" | sed -r 's/restoreScripts//g')

echo $currentBaseDir

tmpDir="$currentBaseDir/tmp"
distributinlistMembersDir="$currentBaseDir/distributinlistMembers"
userpassDir="$currentBaseDir/userpass"
userdataDir="$currentBaseDir/userdata"
filtersDir="$currentBaseDir/filters"
mailDir="$currentBaseDir/mail"

zimbraUser="zimbra"
zmprovBin="/opt/zimbra/bin/zmprov"
zmprovCommnand="sudo -u $zimbraUser $zmprovBin"

zmmailboxBin="/opt/zimbra/bin/zmmailbox"
zmmailboxCommand="sudo -u $zimbraUser $zmmailboxBin"

##############################################

function usage() {

echo "Usage: ./createUser.sh --restore=all"
echo "Usage: ./createUser.sh --restore=test@exampe.com"
echo "--restore         >>>>    restore email or all emails"
exit 1

}

##############################################

for i in "$@"
do
case $i in
        --restore=*)
        restore="${i#*=}"
        shift # past argument=value
        ;;

        *)
            # unknown option
        ;;
esac
done

emailRegex="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
echo $restore

if [[ $restore =~ $emailRegex ]] || [ $restore == "all" ]; then
        echo "restore seems valid input $restore"
else
        echo "restore seems NOT valid input $restore"
        usage
fi

if [[ -z $restore ]]; then
        echo "ERROR: restore parameter is not set"
        usage
fi

if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root. Current user $EUID"
        exit
else
        echo "Current UID is $EUID"
fi

if [ ! -d $distributinlistMembersDir ] || [ ! -d $userpassDir ] || [ ! -d $userdataDir ] || [ ! -d $filtersDir ] || [ ! -d $mailDir ]; then
        echo "some directories are missing."
        echo "check $distributinlistMembersDir"
        echo "check $userpassDir"
        echo "check $userdataDir"
        echo "check $filtersDir"
        echo "check $mailDir"
        exit
fi

if [ $restore == "all" ]; then
        users="<$currentBaseDir/emails.txt"
else
        users=$restore
        grep -qw $users $currentBaseDir/emails.txt
        checkIfEmail=$?
        if [ $checkIfEmail -ne 0 ]; then
                echo "email $users does not exist in archive - $currentBaseDir/emails.txt"
                exit
        fi
fi

for email in $users
do
        $zmprovCommnand -l gaa | grep -q $email
        checkIfAccountExists=$?
        if [[ $checkIfAccountExists -eq 0 ]]; then
                echo "Account $email alredy exists."
        else
                echo "Account $email does NOT exit"
                givenName=$(grep givenName: $userdataDir/$email | cut -d ":" -f2 | sed 's/ //g')
                displayName=$(grep displayName: $userdataDir/$email | cut -d ":" -f2 | sed 's/ //g')
                shadowpass=$(cat $userpassDir/$email.shadow)
                echo "create account $email givenName $givenName displayName $displayName"
                tmpPass="CHANGEme"
                $zmprovCommnand ca $email CHANGEme cn "$givenName" displayName "$displayName" givenName "$givenName"
                checkCreateUser=$?
                if [ $checkCreateUser -eq 0 ]; then
                        echo "user $email created"
                else
                        echo "ERROR could not create $zmprovCommnand ca $email CHANGEme cn $givenName displayName $displayName givenName $givenName"
                fi
                $zmprovCommnand ma $email userPassword $shadowpass
                checkPasswordSet=$?
                if [ $checkPasswordSet -eq 0 ]; then
                        echo "password set on $email"
                else
                        echo "ERROR could not set password for user $email"
                fi

                echo "restore mail for $email"
                $zmmailboxCommand -z -m $email postRestURL "/?fmt=tgz&resolve=skip" $mailDir/$email.tgz
                checkMailRestore=$?
                if [ $checkPasswordSet -eq 0 ]; then
                        echo "mail restored $email"
                else
                        echo "ERROR could not restore mail for $email"
                fi
        fi
done
