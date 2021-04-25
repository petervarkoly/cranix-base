#!/bin/bash -x
#
# Copyright (c) 2016 Peter Varkoly Nürnberg, Germany.  All rights reserved.
#

# other global variable
sysconfig="/etc/sysconfig/cranix"
logdate=`date "+%Y%m%d-%H%M%S"`
logfile="/var/log/cranix-setup.$logdate.log"
passwd=""
windomain=""

# input variable
passwdf=""
all="no"
samba="no"
dhcp="no"
#mail="no"
filter="no"
api="no"
postsetup="no"
accounts="no"
verbose="yes"
cephalixpw=""
registerpw=""


function usage (){
	echo "Usage: cranix-setup.sh --passwdf=/tmp/crx_pswd [OPTION]"
	echo "This is the oss setup script."
	echo
	echo "Options :"
	echo "Mandatory parameters :"
	echo "		--passwdf=<PASSWORDFILE>  Path to the file containing the osspassword."
	echo "Optional parameters :"
	echo "          -h,   --help              Display the help."
	echo "                --all               Setup all services and create the initial groups and user accounts."
	echo "                --samba             Setup the AD-DC samba server."
	echo "                --dhcp              Setup the DHCP server"
	echo "                --mail              Setup the mail server"
	echo "                --filter            Setup the internet filter"
	echo "                --api               Setup the API components"
	echo "                --accounts          Create the initial groups and user accounts"
	echo "                --postsetup         Make additional setups."
	echo "                --cephalixpwf       Path to the file containing the password for the CEPHALIX user."
	echo "                --verbose           Verbose"
	echo "Ex.: ./cranix-setup.sh --passwdf=/tmp/crx_passwd --all"
	exit $1
}

function log() {
    LOG_DATE=`date "+%b %d %H:%M:%S"`
    HOST=`hostname`
    echo "$LOG_DATE $HOST cranix-setup: $1" >> "$logfile"
    if [ "$verbose" = "yes" ]; then
	echo "$1"
    fi
}

function InitGlobalVariable (){

    ########################################################################
    # Avoid running migration scripts:
    mkdir -p /var/adm/cranix/
    touch /var/adm/cranix/migrated-to-cranix

    log "Start InitGlobalVariable"

    ########################################################################
    log " - Read sysconfig file"
    . $sysconfig

    log "   passwd = $passwd"

    ########################################################################
    log " - Set windomain variable"
    windomain=`echo "$CRANIX_DOMAIN" | awk -F"." '{print $1 }' | tr "[:lower:]" "[:upper:]"`
    log "   windomain = $windomain"
    CRANIX_DOMAIN=${CRANIX_DOMAIN,,}
    sed -i s/^CRANIX_DOMAIN=.*/CRANIX_DOMAIN=\"$CRANIX_DOMAIN\"/ $sysconfig
    REALM=${CRANIX_DOMAIN^^}

    log "End InitGlobalVariable"
}

function SetupSamba (){
    log "Start SetupSamba"

    ########################################################################
    log " - Disable AppArmor on smbd, nmbd, winbindd if exists"
    if [ -f "/etc/apparmor.d/usr.sbin.smbd" ] && [ -f "/etc/apparmor.d/usr.sbin.nmbd" ] && [ -f "/etc/apparmor.d/usr.sbin.winbindd" ]; then
	log " - Disable AppArmor on smbd, nmbd, winbindd"
	mv /etc/apparmor.d/usr.sbin.smbd     /etc/apparmor.d/disable/
	mv /etc/apparmor.d/usr.sbin.nmbd     /etc/apparmor.d/disable/
	mv /etc/apparmor.d/usr.sbin.winbindd /etc/apparmor.d/disable/
	systemctl restart apparmor.service
    fi

    ########################################################################
    log " - Clean up befor samba config"
    mkdir -p /etc/samba-backup-$logdate
    mv /etc/krb5.conf /etc/krb5.conf.$logdate
    cp -r /etc/samba/ /etc/samba-backup-$logdate
    rm -r /etc/samba/*

    ########################################################################
    log " - Install domain provision"
    samba-tool domain provision --realm="$CRANIX_DOMAIN" \
				--domain="$windomain" \
				--adminpass="$passwd" \
				--server-role=dc \
				--use-rfc2307 \
				--host-ip="$CRANIX_SERVER" \
				--option="interfaces=127.0.0.1 $CRANIX_SERVER" \
				--option="bind interfaces only=yes"

    ########################################################################
    log " - Config resolv.conf"
    sed -i "s/nameserver .*/nameserver $CRANIX_SERVER/" /etc/resolv.conf

    ########################################################################
    log " - Start samba service"
    systemctl enable samba-ad.service
    systemctl restart samba-ad.service

    ########################################################################
    log " - Setup samba private krbconf to kerberos conf"
    cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

    ########################################################################
    log " - Tell nsswitch to use winbind."
    cp /usr/share/cranix/setup/templates/nsswitch.conf /etc/nsswitch.conf

    ########################################################################
    log " - Create linked groups directory "
    mkdir -p -m 755 $CRANIX_HOME_BASE/groups/LINKED/
    mkdir -p -m 755 $CRANIX_HOME_BASE/${windomain}
    mkdir -p /home/sysadmins/administrator
    ln -s /home/sysadmins/administrator /home/${windomain}/administrator

    ########################################################################
    log " - Create dns entries "
    samba-tool dns add localhost $CRANIX_DOMAIN mailserver   A $CRANIX_MAILSERVER    -U Administrator%"$passwd"
    samba-tool dns add localhost $CRANIX_DOMAIN cranix       A $CRANIX_MAILSERVER    -U Administrator%"$passwd"
    samba-tool dns add localhost $CRANIX_DOMAIN proxy        A $CRANIX_PROXY         -U Administrator%"$passwd"
    samba-tool dns add localhost $CRANIX_DOMAIN backup       A $CRANIX_BACKUP_SERVER -U Administrator%"$passwd"
    samba-tool dns add localhost $CRANIX_DOMAIN install      A $CRANIX_SERVER        -U Administrator%"$passwd"
    samba-tool dns add localhost $CRANIX_DOMAIN timeserver   A $CRANIX_SERVER        -U Administrator%"$passwd"
    samba-tool dns add localhost $CRANIX_DOMAIN wpad         A $CRANIX_SERVER        -U Administrator%"$passwd"
    if [ $CRANIX_NETBIOSNAME != "admin" ]; then
       samba-tool dns add localhost $CRANIX_DOMAIN admin   A $CRANIX_SERVER        -U Administrator%"$passwd"
    fi
    /usr/share/cranix/setup/scripts/create-revers-domain.py "$passwd" $CRANIX_DOMAIN $CRANIX_NETWORK $CRANIX_NETMASK \
	   "mailserver:$CRANIX_MAILSERVER,proxy:$CRANIX_PROXY,backup:$CRANIX_BACKUP_SERVER,admin:$CRANIX_SERVER,router:$CRANIX_NET_GATEWAY"

    #Add rfc2307 attributes to Administartor
    DN=$( /usr/sbin/crx_get_dn.sh Administrator )
    echo "$DN
changetype: modify
add: uid
uid: administrator
-
add: uidNumber
uidNumber: 0
-
add: unixHomeDirectory
unixHomeDirectory: /home/sysadmins/administrator
-
add: gidNumber
gidNumber: 100
-
add: loginShell
loginShell: /bin/bash
-
add: msSFU30NisDomain
msSFU30NisDomain: iqondns
-
add: msSFU30Name
msSFU30Name: administrator
-
add: homeDirectory
homeDirectory: \\\\admin\\administrator
-
add: homeDrive
homeDrive: Z:
-
add: scriptPath
scriptPath: administrator.bat
-
add: profilePath
profilePath: \\\\admin\\profiles\\administrator
"  > /tmp/rfc2307-Administartor
     ldbmodify  -H /var/lib/samba/private/sam.ldb  /tmp/rfc2307-Administartor
     #rm /tmp/rfc2307-Administartor

    #########################################################################
    log " - Some additional samba settings -"
    samba-tool domain passwordsettings set --max-pwd-age=365

    for i in /usr/share/cranix/templates/*.ini
    do
        b=$( basename $i .ini )
        sed "s/#PDC-SERVER#/${CRANIX_NETBIOSNAME}/g" $i > /usr/share/cranix/templates/$b
    done

    ########################################################################
    log " - Setup our smb.conf file"
    cp /etc/samba/smb.conf /etc/samba/smb.conf-orig
    if [ "$CRANIX_TYPE" != "business" ]; then
        sed    "s/#NETBIOSNAME#/${CRANIX_NETBIOSNAME}/g" /usr/share/cranix/setup/templates/samba-smb.conf.ini      > /etc/samba/smb.conf
    else
        sed    "s/#NETBIOSNAME#/${CRANIX_NETBIOSNAME}/g" /usr/share/cranix/setup/templates/samba-smb.conf.business > /etc/samba/smb.conf
    fi
    sed -i "s/#REALM#/$REALM/g"                      /etc/samba/smb.conf
    sed -i "s/#CRANIX_DOMAIN#/$CRANIX_DOMAIN/g"      /etc/samba/smb.conf
    sed -i "s/#WORKGROUP#/$windomain/g"              /etc/samba/smb.conf
    sed -i "s/#GATEWAY#/$CRANIX_SERVER_EXT_GW/g"     /etc/samba/smb.conf
    sed -i "s/#IPADDR#/$CRANIX_SERVER/g"             /etc/samba/smb.conf
    sed -i "s#HOMEBASE#$CRANIX_HOME_BASE#g"          /etc/samba/smb.conf

    systemctl restart samba-ad

    ########################################################################
    log " - Setup ntp signd directory rights."
    chown root:chrony /var/lib/samba/ntp_signd/
    chmod 750         /var/lib/samba/ntp_signd/

    ########################################################################
    log " - Add default policy"
    tar -xf /usr/share/cranix/setup/templates/pol.tar -C /var/lib/samba/sysvol/${CRANIX_DOMAIN}/Policies/
    log "End SetupSamba"
}

function SetupDHCP (){
    log "Start SetupDHCP"
    sed    "s/#CRANIX_SERVER#/${CRANIX_SERVER}/g"                   /usr/share/cranix/setup/templates/dhcpd.conf.ini > /usr/share/cranix/templates/dhcpd.conf
    sed -i "s/#CRANIX_DOMAIN#/${CRANIX_DOMAIN}/g"                   /usr/share/cranix/templates/dhcpd.conf
    sed -i "s/#CRANIX_ANON_DHCP_RANGE#/${CRANIX_ANON_DHCP_RANGE}/g" /usr/share/cranix/templates/dhcpd.conf
    sed -i "s/#CRANIX_NETWORK#/${CRANIX_NETWORK}/g"                 /usr/share/cranix/templates/dhcpd.conf
    sed -i "s/#CRANIX_NETMASK#/${CRANIX_NETMASK_STRING}/g"          /usr/share/cranix/templates/dhcpd.conf
    cp /usr/share/cranix/templates/dhcpd.conf /etc/dhcpd.conf
    if [ $CRANIX_USE_DHCP = "yes" ]; then
        . /etc/sysconfig/dhcpd
        if [ -z "$DHCPD_INTERFACE" ]; then
            sed -i 's/^DHCPD_INTERFACE=.*/DHCPD_INTERFACE="ANY"/'   /etc/sysconfig/dhcpd
        fi
        systemctl enable dhcpd
        systemctl start  dhcpd
    fi
    log "End SetupDHCP"
}

function SetupMail (){
    log "Start SetupMail"
    log "End SetupMail"
}

function SetupInternetFilter (){
    if [ ${CRANIX_INTERNET_FILTER} = "proxy" ]; then
        log "Start SetupProxy"
        sed "s/#DOMAIN#/${CRANIX_DOMAIN}/g" /srv/www/admin/proxy.pac.in > /srv/www/admin/proxy.pac
        ln  /srv/www/admin/proxy.pac /srv/www/admin/wpad.dat
        cp /etc/squid/squid.conf.in      /etc/squid/squid.conf
        sed -i s/LimitNOFILE=.*/LimitNOFILE=16384/ /usr/lib/systemd/system/squid.service
        grep -q www.google.de /etc/hosts || echo "216.239.32.20  www.google.de www.google.com www.google.fr www.google.it www.google.hu www.google.en" >> /etc/hosts
        log "End SetupProxy"
    else
	log "Start SetupUnbound"
	/usr/share/cranix/tools/unbound/setup.sh
	log "End SetupUnbound"
    fi
}

function SetupInitialAccounts (){
    log "Start SetupInitialAccounts"

    ########################################################################
    log " - Create base directory"
    mkdir -m 770 -p $CRANIX_HOME_BASE/all
    mkdir -m 755 -p $CRANIX_HOME_BASE/archiv
    mkdir -m 755 -p $CRANIX_HOME_BASE/groups
    mkdir -m 775 -p $CRANIX_HOME_BASE/software
    mkdir -m 755 -p /mnt/backup
    if [ $CRANIX_TEACHER_OBSERV_HOME = 'yes' ]; then
	mkdir -m 750 -p $CRANIX_HOME_BASE/classes
    fi

    if [ "$CRANIX_TYPE" = "cephalix" -o "$CRANIX_TYPE" = "business" -o $CRANIX_TYPE = 'primary' ]; then
	chmod 1777 $CRANIX_HOME_BASE/all
    else
	chmod 1770 $CRANIX_HOME_BASE/all
    fi
    chmod 1775 $CRANIX_HOME_BASE/software


    ########################################################################
    log " - Create internal users"
    registerpw=`mktemp XXXXXXXXXX`
    if [ -z "$cephalixpw" ]; then
	cephalixpw=`mktemp XXXXXXXXXX`
    fi
    samba-tool user setexpiry --noexpiry Administrator
    samba-tool domain passwordsettings set --complexity=off
    samba-tool user create cephalix "$cephalixpw"
    samba-tool group addmembers "Domain Admins" cephalix
    sed -i s/REGISTERPW/$registerpw/ /opt/cranix-java/conf/cranix-api.properties
    samba-tool user setexpiry --noexpiry cephalix
    samba-tool user create register "$registerpw"
    samba-tool user setexpiry --noexpiry register
    samba-tool group addmembers "Administrators" register
    samba-tool user create ossreader ossreader
    samba-tool user setexpiry --noexpiry ossreader

    ########################################################################
    sysadmins_gn=4000000
    workstations_gn=4000001
    administration_ng=4000002
    templates_gn=4000003
    students_gn=4000004
    teachers_gn=4000005

    ########################################################################
    log " - Create base roles"
    /usr/share/cranix/setup/scripts/crx-add-group.sh --name="SYSADMINS"      --description="Sysadmins"      --type="primary" --mail="sysadmins@$CRANIX_DOMAIN"      --gid-number=$sysadmins_gn
    samba-tool ou create OU=sysadmins
    /usr/share/cranix/setup/scripts/crx-add-group.sh --name="WORKSTATIONS"   --description="Workstations"   --type="primary" --mail="workstations@$CRANIX_DOMAIN"   --gid-number=$workstations_gn
    samba-tool ou create OU=workstations
    /usr/share/cranix/setup/scripts/crx-add-group.sh --name="ADMINISTRATION" --description="Administration" --type="primary" --mail="administration@$CRANIX_DOMAIN" --gid-number=$administration_ng
    samba-tool ou create OU=administration
    /usr/share/cranix/setup/scripts/crx-add-group.sh --name="TEMPLATES"      --description="Templates"      --type="primary" --mail="templates@$CRANIX_DOMAIN"      --gid-number=$templates_gn
    samba-tool ou create OU=templates
    samba-tool ou create OU=guests
    if [ $CRANIX_TYPE != "business" ]; then
        /usr/share/cranix/setup/scripts/crx-add-group.sh --name="STUDENTS"       --description="Students"       --type="primary" --mail="students@$CRANIX_DOMAIN"   --gid-number=$students_gn
        samba-tool ou create OU=students
        /usr/share/cranix/setup/scripts/crx-add-group.sh --name="TEACHERS"       --description="Teachers"       --type="primary" --mail="teachers@$CRANIX_DOMAIN"   --gid-number=$teachers_gn
        samba-tool ou create OU=teachers
    fi
    samba-tool group addmembers "Sysadmins" register
    ########################################################################
    #log " - Create primary group type and add base role to primary group"
    #samba-tool group add "primary" --description="Primary group for role"
    #samba-tool group addmembers "primary" "sysadmins,students,teachers,workstations,administration,templates"

    ########################################################################
    log " - sysadmins primary group add to Domain Admins group"
    samba-tool group addmembers "Domain Admins" "SYSADMINS"
    log " - add to Domain Admins group SePrintOperatorPrivilege"
    net rpc rights grant "$windomain\\Domain Admins" SePrintOperatorPrivilege -U Administrator%"$passwd"
    #net rpc rights grant "$windomain\\Sysadmins" SePrintOperatorPrivilege -U Administrator%"$passwd"


    ########################################################################
    log " - Create base template users"
    /usr/share/cranix/setup/scripts/crx-add-user.sh --uid="tadministration" --givenname="Default profile" --surname="for administration" --role="templates" --password="$passwd" --groups="" --uid-number=4000011
    if [ $CRANIX_TYPE != "business" ]; then
        /usr/share/cranix/setup/scripts/crx-add-user.sh --uid="tstudents"       --givenname="Default profile" --surname="for students"       --role="templates" --password="$passwd" --groups="" --uid-number=4000012
        /usr/share/cranix/setup/scripts/crx-add-user.sh --uid="tteachers"       --givenname="Default profile" --surname="for teachers"       --role="templates" --password="$passwd" --groups="" --uid-number=4000013
        /usr/share/cranix/setup/scripts/crx-add-user.sh --uid="tworkstations"   --givenname="Default profile" --surname="for workstations"   --role="templates" --password="$passwd" --groups="" --uid-number=4000014
    fi

    samba-tool domain passwordsettings set --complexity=on


    ########################################################################
    log " - Create base directory rights"
    case $CRANIX_TYPE in
      cephalix)
        chgrp        $sysadmins_gn           $CRANIX_HOME_BASE/software
	;;
      business)
        chgrp        $sysadmins_gn           $CRANIX_HOME_BASE/software
	;;
      primary)
        chgrp        $teachers_gn           $CRANIX_HOME_BASE/software
        setfacl -m g:$students_gn:rx        $CRANIX_HOME_BASE/software
	;;
      *)
	setfacl -m m::rwx                   $CRANIX_HOME_BASE/all
	setfacl -m g:$teachers_gn:rwx       $CRANIX_HOME_BASE/all
	setfacl -m g:$students_gn:rwx       $CRANIX_HOME_BASE/all
	setfacl -m g:$sysadmins_gn:rwx      $CRANIX_HOME_BASE/all

	chgrp        $teachers_gn           $CRANIX_HOME_BASE/software
	setfacl -m g:$students_gn:rx        $CRANIX_HOME_BASE/software
	setfacl -m g:$sysadmins_gn:rwx      $CRANIX_HOME_BASE/software
    esac

    ########################################################################
    log " - Create itool directory and right "
    mkdir -p /srv/itool/{config,hwinfo,images,ROOT}
    chmod 755  /srv/itool
    chmod 4770 /srv/itool/{config,hwinfo,images}
    chmod 755  /srv/itool/ROOT
    setfacl -m    g::rwx /srv/itool/images
    setfacl -d -m g::rwx /srv/itool/images
    chgrp -R $sysadmins_gn /srv/itool
    setfacl -m    g:$workstations_gn:rx /srv/itool/{config,images}
    setfacl -d -m g:$workstations_gn:rx /srv/itool/{config,images}
    if [ "$CRANIX_TYPE" != "business" ]; then
	setfacl -m    g:$teachers_gn:rx /srv/itool/{config,images}
	setfacl -d -m g:$teachers_gn:rx /srv/itool/{config,images}
    fi

    log "End SetupInitialAccounts"
}

function ApiSetup (){
    log "Start PostSetup"

    ########################################################################
    log "Setup ssh key"
    cd /root
    /bin/mkdir .ssh
    /usr/bin/ssh-keygen -t rsa -N '' -f .ssh/id_rsa
    cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
    /bin/chmod 600 /root/.ssh/authorized_keys
    echo 'stricthostkeychecking no' > /root/.ssh/config
    echo '# Copyright (c) Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
. /etc/os-release
FQH=`hostname -f`
PS1="$FQH:\w # "
_bred="$(path tput bold 2> /dev/null; path tput setaf 1 2> /dev/null)"
_sgr0="$(path tput sgr0 2> /dev/null)"
PS1="${PRETTY_NAME} \[$_bred\]$PS1\[$_sgr0\]"
unset _bred _sgr0
' > /root/.profile

    ########################################################################
    log "Start and setup mysql"
    cp /etc/my.cnf.in /etc/my.cnf
    systemctl start  mysql
    systemctl enable mysql
    sleep 5
    SERVER_NETWORK=$( echo $CRANIX_SERVER_NET | gawk -F '/' '{ print $1 }' )
    SERVER_NETMASK=$( echo $CRANIX_SERVER_NET | gawk -F '/' '{ print $2 }' )
    ANON_NETWORK=$( echo $CRANIX_ANON_DHCP_NET | gawk -F '/' '{ print $1 }' )
    ANON_NETMASK=$( echo $CRANIX_ANON_DHCP_NET | gawk -F '/' '{ print $2 }' )

    for i in /opt/cranix-java/data/*-INSERT.sql
    do
	sed -i "s/#SERVER_NETWORK#/${SERVER_NETWORK}/g"		$i
	sed -i "s/#SERVER_NETMASK#/${SERVER_NETMASK}/g"		$i
	sed -i "s/#ANON_NETWORK#/${ANON_NETWORK}/g"		$i
	sed -i "s/#ANON_NETMASK#/${ANON_NETMASK}/g"		$i
	sed -i "s/#CRANIX_NETBIOSNAME#/${CRANIX_NETBIOSNAME}/g"	$i
	sed -i "s/#CRANIX_SERVER#/${CRANIX_SERVER}/g"		$i
	sed -i "s/#CRANIX_MAILSERVER#/${CRANIX_MAILSERVER}/g"	$i
	sed -i "s/#CRANIX_PROXY#/${CRANIX_PROXY}/g"		$i
	sed -i "s/#CRANIX_BACKUP_SERVER#/${CRANIX_BACKUP_SERVER}/g" $i
	sed -i "s/#CRANIX_NETWORK#/${CRANIX_NETWORK}/g"		$i
	sed -i "s/#CRANIX_NETMASK#/${CRANIX_NETMASK}/g"		$i
    done
    mysql < /opt/cranix-java/data/crx-objects.sql
    case $CRANIX_TYPE in
        cephalix)
            mysql CRX < /opt/cranix-java/data/cephalix-objects.sql
            mysql CRX < /opt/cranix-java/data/school-INSERT.sql
            mysql CRX < /opt/cranix-java/data/cephalix-INSERT.sql
	;;
        business)
            mysql CRX < /opt/cranix-java/data/business-INSERT.sql
	;;
	*)
            mysql CRX < /opt/cranix-java/data/school-INSERT.sql
    esac


    ########################################################################
    log "Make mysql secure"
    cd /root
    password=`mktemp XXXXXXXXXX`
    echo "grant all on CRX.* to 'cranix'@'localhost'  identified by '$password'" | mysql
    mysqladmin -u root password $password
echo "[client]
host=localhost
user=root
password=$password" > /root/.my.cnf
chmod 600 /root/.my.cnf

    sed -i s/MYSQLPWD/$password/ /opt/cranix-java/conf/cranix-api.properties
    sed -i s/CRANIX_NETBIOSNAME/${CRANIX_NETBIOSNAME}/ /opt/cranix-java/conf/cranix-api.properties
}

function PostSetup (){
    ########################################################################
    log "Create profile directory"
    mkdir -p  "$CRANIX_HOME_BASE/profiles"
    chgrp 100 "$CRANIX_HOME_BASE/profiles/"
    chmod 1770 "$CRANIX_HOME_BASE/profiles"
    /usr/bin/setfacl --restore=/usr/share/cranix/setup/profiles-acls

    ########################################################################
    if [ ! -e /etc/ssl/servercerts/cacert.pem ]; then
	log "Create Certificates"
	/usr/share/cranix/tools/create_server_certificates.sh -N CA
	/usr/share/cranix/tools/create_server_certificates.sh -N admin
	/usr/share/cranix/tools/create_server_certificates.sh -N cranix
	/usr/share/cranix/tools/create_server_certificates.sh -N proxy
    fi

    ########################################################################
    log "Adapt Apache configuration"
    sed -i 's/^APACHE_MODULES=.*/APACHE_MODULES="actions alias auth_basic authn_file authz_host authz_groupfile authz_core authz_user autoindex cgi dir env expires include log_config mime negotiation setenvif ssl socache_shmcb userdir reqtimeout php5 rewrite authn_core proxy proxy_http proxy_connect headers"/' /etc/sysconfig/apache2
    sed -i 's/^APACHE_SERVER_FLAGS=.*/APACHE_SERVER_FLAGS="SSL"/' /etc/sysconfig/apache2
    sed "s/#DOMAIN#/$CRANIX_DOMAIN/g" /usr/share/cranix/setup/templates/admin_include.conf.ini > /etc/apache2/vhosts.d/admin_include.conf
    sed "s/#DOMAIN#/$CRANIX_DOMAIN/g" /usr/share/cranix/setup/templates/cranix_include.conf.ini   > /etc/apache2/vhosts.d/cranix_include.conf
    mkdir -p /etc/apache2/vhosts.d/{admin,admin-ssl,cranix,cranix-ssl}
    if [ $CRANIX_ISGATE = "yes" ]; then
       sed -i 's/admin:443/admin:443 extip:444/' /etc/apache2/vhosts.d/admin_include.conf
       sed -Ei 's/\s+Listen 443/                Listen 443\n                    Listen 444/' /etc/apache2/listen.conf
    fi
    mkdir -p /srv/www/cranix/
    sed "s/#DOMAIN#/$CRANIX_DOMAIN/g" /usr/share/cranix/setup/templates/cranix-index.html > /srv/www/cranix/index.html
    systemctl enable apache2
    systemctl start  apache2

    ########################################################################
    log "Setup SuSEFirewall2"
    if [ $CRANIX_ISGATE = "yes" ]; then
        sed -i 's/^FW_ROUTE=.*/FW_ROUTE="yes"/'          /etc/sysconfig/SuSEfirewall2
        sed -i 's/^FW_MASQUERADE=.*/FW_MASQUERADE="no"/' /etc/sysconfig/SuSEfirewall2
	echo "## Enable forwarding."                  >  /etc/sysctl.d/cranix.conf
	echo "net.ipv4.ip_forward = 1 "              >>  /etc/sysctl.d/cranix.conf
	echo "net.ipv6.conf.all.forwarding = 1 "     >>  /etc/sysctl.d/cranix.conf
        systemctl enable SuSEfirewall2
    else
        systemctl disable SuSEfirewall2
    fi
    sed -i 's#^FW_CUSTOMRULES=.*#FW_CUSTOMRULES="/etc/sysconfig/scripts/SuSEfirewall2-custom"#' /etc/sysconfig/SuSEfirewall2
    cp /usr/share/cranix/setup/templates/SuSEfirewall2-custom /etc/sysconfig/scripts/SuSEfirewall2-custom

    ########################################################################
    log "Setup Cups"
    cp /etc/cups/cupsd.conf.in /etc/cups/cupsd.conf

    ########################################################################
    log "Prepare roots desktop"
    mkdir -p /root/Desktop/
    cp /etc/skel/Desktop/* /root/Desktop/
    tar xf /usr/share/cranix/setup/templates/needed-files-for-root.tar -C /root/

    ########################################################################
    log "Enable some important services"
    /usr/lib/systemd-presets-branding/branding-preset-states save
    if [ "$CRANIX_TYPE" = "cephalix"  ]; then
        systemctl enable  cephalix-api
        systemctl disable cranix-api
    fi

    ########################################################################
    log "Generate password file templates"
    sed "s/CRANIX_NAME/$CRANIX_NAME/" /usr/share/cranix/templates/password.html.in > /usr/share/cranix/templates/password.html

    ########################################################################
    log "Enable icons for gnome 3.0"
    gsettings set org.gnome.desktop.background show-desktop-icons true

    ########################################################################
    log "Enable user and group quota"
    sed -i 's#/home  xfs   defaults#/home  xfs   usrquota,grpquota#' /etc/fstab
    mount -o remount,usrquota,grpquota /home

    ########################################################################
    log "Timeserver setup"
    /usr/share/cranix/setup/scripts/setup-chrony.sh
    log "End PostSetup"

}


if [ ! -f $sysconfig ]; then
        echo -e "\033[0;31;1mThis script is for CRANIX only!\033[\0m"
        echo -e "\033[0;31;1m*********         exiting         *********\033[\0m"
        exit 0
fi

if [ -z "$1" ]
then
   usage 0
fi

while [ "$1" != "" ]; do
    case $1 in
	-h|-H|--help)
				usage 0
	;;
	--passwdf=* )
				passwdf=$(echo $1 | sed -e 's/--passwdf=//g');
				passwd=$( cat $passwdf )
				if [ ! "$passwd" ]
				then
					usage 0
				fi
	;;
	--cephalixpwf=* )
				cephalixpwf=$(echo $1 | sed -e 's/--cephalixpwf=//g');
				cephalixpw=$( cat $cephalixpwf )
				if [ ! "$cephalixpw" ]
				then
					usage 0
				fi
	;;
	--all )
				all="yes"
	;;
	--samba )
				samba="yes"
        ;;
	--dhcp )
                                dhcp="yes"
        ;;
	--mail )
                                mail="yes"
        ;;
	--filter )
				filter="yes"
        ;;
	--api )
				api="yes"
        ;;
	--accounts )
                                accounts="yes"
        ;;
	--postsetup )
                                postsetup="yes"
        ;;
	--verbose )
                                verbose="yes"
        ;;
	\?)
                echo "UNKNOWN argument \"-$OPTARG\"." >&2
                usage 1
                ;;
        :)
                echo "Option \"-$OPTARG\" needs an argument." >&2
                usage 1
                ;;
        *)
                echo "Wrong arguments" >&2
                usage 1
                ;;
    esac
    shift
done

InitGlobalVariable
if [ "$all" = "yes" ] || [ "$samba" = "yes" ]; then
    SetupSamba
fi
if [ "$all" = "yes" ] || [ "$dhcp" = "yes" ]; then
    SetupDHCP
fi
if [ "$all" = "yes" ] || [ "$mail" = "yes" ]; then
    SetupMail
fi
if [ "$all" = "yes" ] || [ "$accounts" = "yes" ]; then
    SetupInitialAccounts
fi
if [ "$all" = "yes" ] || [ "$api" = "yes" ]; then
    ApiSetup
fi
if [ "$all" = "yes" ] || [ "$filter" = "yes" ]; then
    SetupInternetFilter
fi
if [ "$all" = "yes" ] || [ "$postsetup" = "yes" ]; then
    PostSetup
fi

chmod 600 $logfile
exit 0
