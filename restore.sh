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

users="$currentBaseDir/emails.txt"

while read email
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
done < $users
