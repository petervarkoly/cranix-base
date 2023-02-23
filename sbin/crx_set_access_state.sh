#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
#
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2005 Peter Varkoly Fuerth, Germany.  All rights reserved.
# Copyright (c) 2002 SuSE Linux AG Nuernberg, Germany.  All rights reserved.
#
# $Id: control_access,v 2.4 2007/05/09 21:24:06 pv Exp $
#
# syntax: /usr/sbin/crx_set_access_state  1|0 network direct|proxy|internet|login|printing|portal [IP of not controlled ws]
#


STATE=$( /usr/sbin/crx_get_access_state.sh $2 $3 )
if [ "$STATE" = "$1" ]; then
        exit;
fi

. /etc/sysconfig/cranix

export NETWORK="$CRANIX_SERVER/$CRANIX_NETMASK";

case "$3" in
   direct)
	if test "$CRANIX_ISGATE" = "no"; then
                echo -n '1'
                exit 0
	fi
	export DEST=$CRANIX_NET_GATEWAY
	;;
   proxy|internet)
        if [ "CRANIX_USE_TFK" = "yes" ]; then
                echo -n '1'
                exit 0
        fi
	export DEST=$CRANIX_PROXY
	;;
   printing)
	export DEST=$CRANIX_PRINTSERVER
	;;
   portal)
	export DEST=$CRANIX_MAILSERVER
	;;
   login)
	export DEST=$CRANIX_SERVER
	;;
esac

LOCAL=`/sbin/ip addr | /usr/bin/grep "$DEST/"`

case "$3" in
   direct)
	DEV=$( ip route show | gawk '{ if( $1 == "default" ) { print $5; exit; } }' )
	if test "$1" = "1"; then
		IFS=$'\n'; i=0; e=0; n=0;
		for l in $( /usr/sbin/iptables -t filter -S forward_int ); do n=$((n+1)); echo $l | /usr/bin/grep -q 'j ACCEPT' && i=$n; done;
		n=0;
		for l in $( /usr/sbin/iptables -t filter -S forward_ext ); do n=$((n+1)); echo $l | /usr/bin/grep -q 'j ACCEPT' && e=$n; done;
		COMMAND="/usr/sbin/iptables -I forward_ext $e -s $2 ! -d $NETWORK -j ACCEPT -m state --state NEW,RELATED,ESTABLISHED"
		COMMAND="$COMMAND; /usr/sbin/iptables -I forward_ext $e -d $2 -j ACCEPT -m state --state RELATED,ESTABLISHED"
		COMMAND="$COMMAND; /usr/sbin/iptables -I forward_int $i -s $2 -j ACCEPT -m state --state NEW,RELATED,ESTABLISHED"
		COMMAND="$COMMAND; /usr/sbin/iptables -I forward_int $i -d $2 -j ACCEPT -m state --state RELATED,ESTABLISHED"
		COMMAND="$COMMAND; /usr/sbin/iptables -I POSTROUTING -s $2 -o ${DEV} -j MASQUERADE -t nat;"
	else
		COMMAND="/usr/sbin/iptables -D forward_ext -s $2 ! -d $NETWORK -j ACCEPT -m state --state NEW,RELATED,ESTABLISHED &> /dev/null"
		COMMAND="$COMMAND; /usr/sbin/iptables -D forward_ext -d $2 -j ACCEPT -m state --state RELATED,ESTABLISHED &> /dev/null"
		COMMAND="$COMMAND; /usr/sbin/iptables -D forward_int -s $2 -j ACCEPT -m state --state NEW,RELATED,ESTABLISHED &> /dev/null"
		COMMAND="$COMMAND; /usr/sbin/iptables -D forward_int -d $2 -j ACCEPT -m state --state RELATED,ESTABLISHED &> /dev/null"
		COMMAND="$COMMAND; while /usr/sbin/iptables -D POSTROUTING -s $2 -o ${DEV} -j MASQUERADE -t nat ; do false; done &> /dev/null"
	fi
	;;
   proxy|internet|printing|portal)
	if test "$1" = "1"; then
	      COMMAND="while /usr/sbin/iptables -D INPUT -s $2 -j $3-$2; do false; done &> /dev/null"
	      COMMAND="$COMMAND; /usr/sbin/iptables -F $3-$2 &> /dev/null"
	      COMMAND="$COMMAND; /usr/sbin/iptables -X $3-$2 &> /dev/null"
	else
	      COMMAND="/usr/sbin/iptables -N $3-$2  &> /dev/null"
	      COMMAND="$COMMAND; /usr/sbin/iptables -I $3-$2  -s $2 -d $DEST -j REJECT &> /dev/null"
	      if test $4
	      then
	        COMMAND="$COMMAND; /usr/sbin/iptables -I $3-$2  -s $4 -j  ACCEPT &> /dev/null"
	      fi
	      COMMAND="$COMMAND; /usr/sbin/iptables -I INPUT -s $2 -j $3-$2 &> /dev/null"
	fi
	;;
   login)
	if test "$1" = "1"; then
	      COMMAND="while /usr/sbin/iptables -D INPUT -s $2 -j $3-$2; do false; done &> /dev/null"
	      COMMAND="$COMMAND; /usr/sbin/iptables -F $3-$2 &> /dev/null"
	      COMMAND="$COMMAND; /usr/sbin/iptables -X $3-$2 &> /dev/null"
	else
	      COMMAND="/usr/sbin/iptables -N $3-$2  &> /dev/null"
              COMMAND="$COMMAND; /usr/sbin/iptables -I $3-$2  -s $2 -d $DEST -p tcp --destination-port 139 -j REJECT -m state --state NEW         &> /dev/null"
              COMMAND="$COMMAND; /usr/sbin/iptables -I $3-$2  -s $2 -d $DEST -p tcp --destination-port 139 -j ALLOW  -m state --state ESTABLISHED &> /dev/null"
              COMMAND="$COMMAND; /usr/sbin/iptables -I $3-$2  -s $2 -d $DEST -p tcp --destination-port 445 -j REJECT &> /dev/null"
	      if test $4
	      then
	        COMMAND="$COMMAND; /usr/sbin/iptables -I $3-$2  -s $4 -j  ACCEPT &> /dev/null"
	      fi
	      COMMAND="$COMMAND; /usr/sbin/iptables -I INPUT -s $2 -j $3-$2 &> /dev/null"
	fi
	;;
esac
if [ "$COMMAND" ]; then
   if [ "$LOCAL" ]; then
     eval $COMMAND
   else
     ssh $DEST $COMMAND
   fi
fi
