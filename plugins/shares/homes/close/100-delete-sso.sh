#!/bin/bash
U=$1
I=$2
a=$3
m=$4
R=$5


/usr/sbin/crx_api.sh DELETE devices/loggedInUsers/$I/$U

. /etc/sysconfig/cranix

role=$( /usr/sbin/crx_api_text.sh GET users/byUid/$U/role )

case "${role}" in
        workstations)
        ;;
        students)
                if [ "${CRANIX_ALLOW_STUDENTS_MULTIPLE_LOGIN}" = "no" ]; then
                        DN=$( crx_get_dn.sh ${U} )
                fi
        ;;
        *)
                if [ "${CRANIX_ALLOW_MULTIPLE_LOGIN}" = "no" ]; then
                        DN=$( crx_get_dn.sh ${U} )
                fi
esac

if [ "${DN}" ]; then
        tmpldif=$( mktemp /tmp/XXXXXXXX )
        echo "${DN}" > ${tmpldif};
        echo "changetype: modify
delete: userWorkstations" >> ${tmpldif}
        ldbmodify  -H /var/lib/samba/private/sam.ldb ${tmpldif}
        rm -f ${tmpldif}

fi

