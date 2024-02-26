#!/bin/bash
# zimbra-export.sh

################################################################################
#                                                                              #
#  This script will export all the accounts of a single domain to a Zimbra     #
#  server. For each account, it will export its content (briefcase, calendar,  #
#  conversations, contacts, deleted messages, emailed contacts, inbox, sent,   #
#  sent messages and tasks) to a zip file. It will also export each account's  #
#  password (encrypted) and profile name (class of service = cos) to both      #
#  single files.                                                               #
#                                                                              #
#  Tested with Zimbra Collaboration Open Source 8.8.15 in Ubuntu 16.04.6 LTS   #
#                                                                              #
################################################################################

# Check if it runs as root or with sudo privileges
if [ $USER != root ]
then
    echo -e "\nError: it must be executed as root or with sudo privileges.\n"
    exit
fi

# Domain
DOMAIN=mydomain.com

# Target folder
BKDIR=/tmp/${DOMAIN}

# It creates the target folder if it doesn't exist
if [ ! -d $BKDIR ]
then
    echo -e "\nFolder $BKDIR doesn't exist."
    mkdir -p $BKDIR
    echo "Folder $BKDIR created."
fi

# Ordered list with all accounts (gaa = get all accounts) in the domain
echo -e "\nGetting accounts from the server ..."
LIST=`/opt/zimbra/bin/zmprov -l gaa $DOMAIN | sort`

# Total number of accounts
TOTAL=`echo $LIST | wc -w`

# Counter
COUNT=0

# Associative array which will contain all the existing profiles in the server in pairs id-name
declare -A cos_array

# Individual export of all accounts, passwords and profiles
for ACCOUNT in $LIST
do

    COUNT=`expr $COUNT + 1`
    echo -e "\nProcessing $ACCOUNT ... $COUNT of ${TOTAL}."

    # Exported files will be named as username.extension
    USERNAME=`echo $ACCOUNT | cut -d'@' -f 1`

    # Special accounts will not be exported
    case $USERNAME in
        admin|galsync.*|ham.*|spam.*|virus-quarantine.*) echo "Special account NOT exported."
        continue
    esac

    # Exporting account's content as a zip file
    /opt/zimbra/bin/zmmailbox -z -m $ACCOUNT gru "?fmt=zip&meta=1" > ${BKDIR}/${USERNAME}.zip
    echo "Content exported to ${BKDIR}/${USERNAME}.zip."

    # Getting password and profile id of the account
    ATTRS=`/opt/zimbra/bin/zmprov -l ga $ACCOUNT | grep -E '(userPassword|zimbraCOSId)'`
    PASSWORD=`echo $ATTRS | cut -d' ' -f 2`
    COS_ID=`echo $ATTRS | cut -d' ' -f 4`

    # If the account's password is set, it is exported to a .shadow file
    echo -n "Password "
    if [ -z $PASSWORD ]
    then
        > ${BKDIR}/${USERNAME}.noshadow.empty
        echo "not set."
    else
        echo $PASSWORD > ${BKDIR}/${USERNAME}.shadow
        echo "exported to ${BKDIR}/${USERNAME}.shadow."
    fi

    # If the account's profile is not default, its name is exported to a .cos file
    echo -n "Account's profile "
    if [ -z $COS_ID ]
    then
        > ${BKDIR}/${USERNAME}.nocos.empty
        echo "is default."
    else
        COS_NAME=`echo ${cos_array[$COS_ID]}`
        if [ -z $COS_NAME ]
        then
            COS_NAME=`/opt/zimbra/bin/zmprov gc $COS_ID | grep cn: | awk '{print $2}'`
            cos_array+=([$COS_ID]=$COS_NAME)
        fi
        echo $COS_NAME > ${BKDIR}/${USERNAME}.cos
        echo "exported to ${BKDIR}/${USERNAME}.cos."
    fi

done

# Change user and group of exported files
chown zimbra.zimbra ${BKDIR}

echo -e "\nExport process to ${BKDIR} completed.\n"
