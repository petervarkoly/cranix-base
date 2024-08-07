#!/bin/bash

U=$1
I=$2
a=$3
m=$4
R=$5
F=$6

id ${U} &>/dev/null || exit

. /etc/sysconfig/cranix

if [ -z "${CRANIX_PRINTSERVER_NETBIOSNAME}" ]; then
	CRANIX_PRINTSERVER_NETBIOSNAME="printserver"
fi

if [ -z "${CRANIX_FILESERVER_NETBIOSNAME}" ]; then
	CRANIX_FILESERVER_NETBIOSNAME="${CRANIX_NETBIOSNAME}"
fi
if [ "${F}" ]; then
        CRANIX_FILESERVER_NETBIOSNAME="${CRANIX_FILESERVER_NETBIOSNAME}.${CRANIX_DOMAIN}"
fi

role=$( /usr/sbin/crx_api_text.sh GET users/byUid/$U/role )
mkdir -p /var/lib/samba/sysvol/$R/scripts
setfacl -m g:users:rx /var/lib/samba/sysvol/
setfacl -m g:users:rx /var/lib/samba/sysvol/$R/
setfacl -m g:users:rx /var/lib/samba/sysvol/$R/scripts/
if [ -e /usr/share/cranix/templates/login-${role}.bat ]; then
	sed "s/#FILE-SERVER#/${CRANIX_FILESERVER_NETBIOSNAME}/" /usr/share/cranix/templates/login-${role}.bat > /var/lib/samba/sysvol/$R/scripts/${U}.bat
else
	sed "s/#FILE-SERVER#/${CRANIX_FILESERVER_NETBIOSNAME}/" /usr/share/cranix/templates/login-default.bat > /var/lib/samba/sysvol/$R/scripts/${U}.bat
fi

if [ -x /usr/share/cranix/tools/custom_create_logon_script.sh ]; then
	/usr/share/cranix/tools/custom_create_logon_script.sh ${U} ${I} ${a} ${m} ${R} ${role}
fi

if [ "${CRANIX_CLEAN_UP_PRINTERS}" = "yes"  -a -e /usr/share/cranix/templates/copy_and_run_rem_printers ]; then
	sed "s/#FILE-SERVER#/${CRANIX_FILESERVER_NETBIOSNAME}/" /usr/share/cranix/templates/copy_and_run_rem_printers >> /var/lib/samba/sysvol/$R/scripts/${U}.bat
fi

if [ "$role" = "students" ]; then
        if [ "${CRANIX_MOVE_STUDENTS_PROFILE_TO_HOME}" = "no" ]; then
                CRANIX_MOVE_PROFILE_TO_HOME="no"
        fi
        if [ "${CRANIX_TEACHER_OBSERV_HOME}" = "yes" ]; then
                CRANIX_MOVE_PROFILE_TO_HOME="no"
        fi
fi
if [ "${CRANIX_MOVE_PROFILE_TO_HOME}" = "yes" ]; then
	userHome=$( crx_get_home.sh ${U} )
	if [ -z "${userHome}" -o ${userHome/${CRANIX_HOME_BASE}/} = ${userHome} ]; then
                echo "ERROR create-logon-script: '$U' has not home directory"
        else
		cat /usr/share/cranix/templates/login-profile-move-registy-patch >> /var/lib/samba/sysvol/$R/scripts/${U}.bat
	        install -o ${U} -m 700 -d ${userHome}/{Documents,Downloads,Favorites,Pictures,WinDesktop,Videos,Music,AppData,OneDrive}
	fi
else
	cat /usr/share/cranix/templates/login-profile-move-back-registy-patch >> /var/lib/samba/sysvol/$R/scripts/${U}.bat
fi

if [ "${CRANIX_LOGON_CONNECT_PRINTERS,,}" != "no" ]; then
	defaultPrinter=$( /usr/sbin/crx_api.sh GET devices/byIP/$I/defaultPrinter )
	if [ "$defaultPrinter" ]; then
		printf "rundll32 printui.dll,PrintUIEntry /q /in /n \134\134${CRANIX_PRINTSERVER_NETBIOSNAME}\134${defaultPrinter} /j\"Default ${defaultPrinter}\"\r\n" >> /var/lib/samba/sysvol/$R/scripts/${U}.bat;
		printf "rundll32 printui.dll,PrintUIEntry /y /n \134\134${CRANIX_PRINTSERVER_NETBIOSNAME}\134${defaultPrinter} /j\"Default ${defaultPrinter}\"\r\n"     >> /var/lib/samba/sysvol/$R/scripts/${U}.bat;
	fi
	for printer in $( /usr/sbin/crx_api.sh GET devices/byIP/$I/availablePrinters )
	do
		printf "rundll32 printui.dll,PrintUIEntry /q /in /n \134\134${CRANIX_PRINTSERVER_NETBIOSNAME}\134${printer} /j\"${printer}\"\r\n" >> /var/lib/samba/sysvol/$R/scripts/${U}.bat;
	done
fi

chown ${U} /var/lib/samba/sysvol/$R/scripts/${U}.bat
setfacl -m m::rwx /var/lib/samba/sysvol/$R/scripts/${U}.bat

