#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
# Copyright (c) Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

arg=$1

if [ "$arg" = "--help" -o  "$arg" = "-h" ]
then
	echo 'Usage: /usr/share/cranix/tools/reset_home.sh [OPTION]'
	echo 'Resets directories in /home.'
	echo
	echo 'Options :'
	echo 'Mandatory parameters :'
	echo "		No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo 'Optional parameters :'
	echo '		-h,   --help         Display this help.'
	echo '		-d,   --description  Display the descriptiont.'
	echo '		-a,   --all          Resets all directories in /home recursively including profiles and home directories of the users.'
	exit
fi

if [ "$arg" = "--description" -o  "$arg" = "-d" ]
then
	echo 'NAME:'
	echo '	reset_home.sh'
	echo 'DESCRIPTION:'
	echo '	Resets directories in /home.'
	echo 'PARAMETERS:'
	echo '	MANDATORY:'
	echo "		                    : No need for mandatory parameters. (There's no need for parameters for running this script.)"
	echo '	OPTIONAL:'
	echo '		-h,   --help        : Display this help.(type=boolean)'
	echo '		-d,   --description : Display the descriptiont.(type=boolean)'
	echo '		-a,   --all         : Resets all directories in /home recursively including profiles and home directories of the users.(type=boolean)'
	exit
fi

. /etc/sysconfig/cranix

/bin/chown root /home/*

/bin/mkdir -p  /home/groups
/bin/chmod 755 /home/groups
/usr/bin/setfacl -b /home/groups
/bin/mkdir -p  /home/profiles
/usr/bin/setfacl --restore=/usr/share/cranix/setup/profiles-acls
/bin/mkdir -p  /home/templates
/bin/chmod 750 /home/templates
/bin/mkdir -p  /home/all
if [ "$CRANIX_TYPE" = "cephalix" -o "$CRANIX_TYPE" = "business" -o $CRANIX_TYPE = 'primary' ]
then
        /bin/chmod    1777   /home/all
else
        /bin/chmod    1770   /home/all
	/usr/bin/setfacl -Rb                       /home/all
	/usr/bin/setfacl -Rm  m::rwx               /home/all
	/usr/bin/setfacl -Rm  g:teachers:rwx       /home/all
	/usr/bin/setfacl -Rm  g:students:rwx       /home/all
	/usr/bin/setfacl -Rm  g:administration:rwx /home/all
	/usr/bin/setfacl -Rdm m::rwx               /home/all
	/usr/bin/setfacl -Rdm g:teachers:rwx       /home/all
	/usr/bin/setfacl -Rdm g:students:rwx       /home/all
	/usr/bin/setfacl -Rdm g:administration:rwx /home/all
fi
/bin/mkdir -p   /home/software
/bin/chmod 1775 /home/software

/bin/chgrp 	 templates /home/templates

for cn in $( /usr/sbin/crx_api_text.sh GET groups/text/byType/primary )
do
        name=$( echo "$cn" | tr "[:lower:]" "[:upper:]" )
        if [ "$name" = "STUDENTS" ]
        then
                continue
        fi
        mkdir -m 770 -p /home/groups/${name}
        chgrp -R $cn /home/groups/${name}
done

if test -d /home/groups/STUDENTS
then
	/usr/bin/setfacl -b                     /home/groups/STUDENTS
	/usr/bin/setfacl -m g:teachers:rx       /home/groups/STUDENTS
	/usr/bin/setfacl -d -m g:teachers:rx    /home/groups/STUDENTS
fi

if [ "$arg" = "-a" -o  "$arg" = "--all" ]
then
    IFS=$'\n'
    for cn in $( /usr/sbin/crx_api_text.sh GET groups/text/byType/class )
    do
        g=$( echo $cn|tr '[:lower:]' '[:upper:]' )
        i="/home/groups/$g"
        /bin/mkdir -p  "$i"
        gid=`/usr/sbin/crx_get_gidNumber.sh "$cn"`
        if [ "$gid" ] 
        then
            chgrp -R $gid  "$i"
            /usr/bin/setfacl -P -R -b "$i"
	    find "$i" -type d -exec /usr/bin/chmod o-t,g+rwx {} \;
	    find "$i" -type d -exec /usr/bin/setfacl -d -m g:$gid:rwx {} \;
            echo "Repairing $i"
        else
       	   echo "Class $cn do not exists. Can not repair $i"
        fi
    done
    IFS=$'\n'
    for cn in $( /usr/sbin/crx_api_text.sh GET groups/text/byType/workgroup )
    do
        g=$( echo $cn|tr '[:lower:]' '[:upper:]' )
        i="/home/groups/$g"
        /bin/mkdir -p  "$i"
        gid=`/usr/sbin/crx_get_gidNumber.sh "$cn"`
        if [ "$gid" ] 
        then
            chgrp -R $gid  "$i"
            /usr/bin/setfacl -P -R -b "$i"
	    find "$i" -type d -exec /usr/bin/chmod o-t,g+rwx {} \;
	    find "$i" -type d -exec /usr/bin/setfacl -d -m g:$gid:rwx {} \;
            echo "Repairing $i"
        else
       	   echo "Class $cn do not exists. Can not repair $i"
        fi
    done

    #Repaire TEACHERS and SYSADMINS
    /bin/chmod -R 770 $i
    /usr/bin/setfacl -R -dm o::--- /home/groups/TEACHERS
    /usr/bin/setfacl -R -m  o::--- /home/groups/TEACHERS
    /usr/bin/chmod -R o-x /home/groups/TEACHERS

    for cn in $( /usr/sbin/crx_api_text.sh GET groups/text/byType/primary )
    do
        /usr/bin/setfacl -b /home/$cn
        /usr/bin/chmod 755  /home/$cn
        for uid in $( /usr/sbin/crx_api.sh GET users/uidsByRole/$cn )
	do
	    i=$( /usr/sbin/crx_get_home.sh $uid)
	    /bin/mkdir -p $i
	    /usr/bin/setfacl -Rb $i
	    /bin/chmod -R 700 $i
	    /bin/chown -R $uid  $i
	    if [ ! -e /home/${CRANIX_WORKGROUP}/${uid} ]; then
                ln -s $i /home/${CRANIX_WORKGROUP}/${uid}
            fi
	    echo "Repairing $i"
	done
    done
fi

if [ -e /usr/share/cranix/tools/custom_reset_home.sh ]; then
	/usr/share/cranix/tools/custom_reset_home.sh
fi
