#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
#
# Copyright (c) 2017 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
#

FROM=""
TO=""
PROJECT=""
CLEANUP=""

while getopts f:t:p:c:d:h name
do
    case $name in
    f)
       FROM="$OPTARG";;
    t)
       TO="$OPTARG";;
    p)
       PROJECT="$OPTARG";;
    c)
       CLEANUP="$OPTARG";;
    d)
       SORTDIR="$OPTARG";;
    h)
       usage
       exit 0;;
    ?)
       usage
       exit 2;;
    esac
done

. /etc/sysconfig/cranix

if [ ${CRANIX_DEBUG} = "yes" ];  then
   DATE=$( /usr/share/cranix/tools/crx_date.sh )
   echo "DATE=$DATE FROM=$FROM TO=$TO PROJECT=$PROJECT SORTDIR=$SORTDIR CLEANUP=$CLEANUP" >> /tmp/collectfiles
fi

IMPORT="$( crx_get_home.sh ${TO} )/Import/"
if [ $SORTDIR = "y" ]; then
    TARGET="${IMPORT}/${PROJECT}/$FROM"
else
    TARGET="${IMPORT}/${PROJECT}"
fi
mkdir -p -m 700 "${TARGET}"
chown -R $TO "${IMPORT}/${PROJECT}"

USERHOME=$( crx_get_home.sh ${FROM} )
EXPORT="${USERHOME}/Export/"

if [ ! -d $EXPORT ]; then
    echo "The export directory '$EXPORT' does not exists." 1>&2
    exit 1
fi
COUNT=$( ls ${EXPORT} | wc | gawk '{ print $1 }' )
if [ $COUNT -eq 0 ]; then
   echo "The export directory '$EXPORT' is empty." 1>&2
   exit 2
fi

if [ "$SORTDIR" = "y" ]; then
    cp -a $EXPORT/* "${TARGET}/"
else
    IFS=$'\n'
    for i in $EXPORT/*
    do
       j=$( basename "$i" )
       cp "$i" "${TARGET}/${FROM}-${j}"
    done
fi

chown -R $TO "${IMPORT}/${PROJECT}"

if [ "$CLEANUP" = 'y' ]; then
    rm -rf $EXPORT/*
fi

echo $COUNT
