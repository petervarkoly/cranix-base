#!/bin/bash
# Copyright (c) 2021 Peter Varkoly <pvarkoly@cephalix.eu> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
usage ()
{
        echo 'Usage: /usr/share/cranix/tools/find_files_of_user.sh [OPTION]'
        echo 'Tool to find all files created by the user <uid> in the /home directory.'
        echo '(Creates a report of all files created by the user <uid> in the /home directory.'
        echo "The report will be saved in the homedirectory of [myuid] in the directory SearchUsersFiles."
        echo "If myuid is not given the enviroment variable \$USER will be used)"
        echo
        echo 'Options :'
        echo 'Mandatory parameters :'
        echo '                --uid    User uid.(Ex: ./find_files_of_user.sh --uid=pjanos)'
        echo 'Optional parameters :'
        echo '          -h,   --help         Display this help.'
        echo '          -d,   --description  Display the descriptiont.'
        echo '                --myuid        My uid.'

}
if [ -z "$1" ]
then
        usage
        exit
fi

. /etc/sysconfig/cranix
while [ "$1" != "" ]; do
    case $1 in
        --uid=* )
                                u=$(echo $1 | sed -e 's/--uid=//g');
                                if [ "$u" = '' ]
                                then
                                        usage
                                        exit;
                                fi;;
        --myuid=* )
                                myuid=$(echo $1 | sed -e 's/--myuid=//g');
                                if [ "$a" = '' ]
                                then
                                        usage
                                        exit;
                                fi
				report=$( /usr/sbin/crx_get_home.sh $myuid )
				;;
        -h | --help )           usage
                                exit;;
        * )                     usage
                                exit 1
    esac
    shift
done


home=$( /usr/sbin/crx_get_home.sh $u )
date=$( /usr/share/cranix/tools/crx_date.sh )

get_name()
{
        GN=$( /usr/sbin/crx_api_text.sh GET users/byUid/${u}/givenName )
        SN=$( /usr/sbin/crx_api_text.sh GET users/byUid/${u}/surName )
        NAME="$GN $SN"
}
get_name

if [ -z "$report" ]; then
        report=$CRANIX_HOME_BASE/groups/SYSADMINS
fi
mkdir -p $report/SearchUsersFiles/

(
echo "================================================================"
echo "Filesystem Report for $NAME"
echo "================================================================"
echo
echo "================================================================="
echo "Checking file system quota:"
NOQUOTA=$( quota -w  $u 2> /dev/null | grep 'none' )
QUOTA=$( quota -w $u 2> /dev/null | grep '\*' )
if [ "$QUOTA" ]; then
    echo -n "$NAME is over quota: "
    echo $QUOTA | sed 's/\*//' | gawk '{ print "used :", $2/1024, "MB allowed: ", $3/1024, "MB"}'
elif [ "$NOQUOTA" ]; then
    echo "$NAME has no quota"
else
    echo "$NAME is not over quota: "
    quota -w $u 2> /dev/null | grep /dev/ | awk '{ print "used :", $2/1024, "MB allowed: ", $3/1024, "MB"}'
fi
echo "================================================================="
echo
echo "================================================================="
echo "Files of $NAME in $CRANIX_HOME_BASE/all:"
find $CRANIX_HOME_BASE/all      -type f -user $u -printf "%kKB %p \n"
echo "================================================================="
echo
echo "================================================================="
echo "Files of $NAME in $CRANIX_HOME_BASE/groups:"
find $CRANIX_HOME_BASE/groups   -type f -user $u -printf "%kKB %p \n"
echo "================================================================="
echo
echo "================================================================="
echo "Files of $NAME in $CRANIX_HOME_BASE/software:"
find $CRANIX_HOME_BASE/software -type f -user $u -printf "%kKB %p \n"
echo "================================================================="
echo
echo "================================================================="
echo "Windows Profiles of $NAME in MB:"
find $CRANIX_HOME_BASE/profiles/$u.* -maxdepth 1 -type d -exec du -s -BM {} \;
echo "================================================================="
echo
echo "================================================================="
echo "Allocation of $NAME's home directory"
echo "1. Full size:"
du -sh $home
echo
echo "2. Allocation on the first level:"
du -sSh $home
echo
echo "3. The content $NAME's subdirectories in MB. Sorted by size:"
find $home -mindepth 1 -maxdepth 1 -type d -exec du -BM -s {} \; | sort -nr
echo "================================================================="
) > $report/SearchUsersFiles/$u-$date.txt

if [ "$myuid" ]; then
        chown -R $myuid:users $report/SearchUsersFiles/
fi
