#!/bin/bash
#
# Copyright (c) 2012 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
# Copyright (c) 2009 Peter Varkoly Fuerth, Germany.  All rights reserved.
#
# $Id: oss_get_access_status,v 2.1 2007/05/09 21:24:06 pv Exp $
#
# syntax: /usr/sbin/oss_get_access_status network all|proxy|internet|samba|priniting|mailing
#

. /etc/sysconfig/schoolserver
case "$2" in
   all)
        export DEST=$SCHOOL_NET_GATEWAY
        ;;
   internet|proxy)
	if [ "$SCHOOL_USE_TFK" = "yes" ]; then
		echo -n '1'
		exit 0
	fi
        export DEST=$SCHOOL_PROXY
        ;;
   printing)
        export DEST=$SCHOOL_PRINTSERVER
        ;;
   mailing)
        export DEST=$SCHOOL_MAILSERVER
        ;;
   samba)
        export DEST=$SCHOOL_SERVER
        ;;
esac

LOCAL=`ip addr | grep "$DEST/"`

case "$2" in
   all)
#TODO
#We have to mark not full internet access too.
#E.m. if only some ports or server are enabled
	if [ "$LOCAL" ]
	then
		STATUS=`/usr/sbin/iptables -L -t nat -v -n | grep "MASQUERADE.*all.*$1" | grep -P "0.0.0.0/0|$SCHOOL_NETWORK/"`
	else
		STATUS=`ssh $DEST "/usr/sbin/iptables -L -t nat -v -n | grep 'MASQUERADE.*all.*$1' | grep -P '0.0.0.0/0|$SCHOOL_NETWORK/'"`
	fi
	if test "$STATUS"
	then
	  echo -n '1'
	else
	  echo -n '0'
	fi
	exit 0
	;;
   *)
	if [ "$LOCAL" ]
	then
		STATUS=`/usr/sbin/iptables -L -n -v | grep $2-$1`
	else
		STATUS=`ssh $DEST "/usr/sbin/iptables -L -n -v | grep $2-$1"`
	fi
	;;
esac	
if test "$STATUS"
then
  echo -n '0'
else
  echo -n '1'
fi
