#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
# Copyright Dipl Ing Peter Varkoly <peter@varkoly.de>

. /etc/sysconfig/cranix

for i in ${CRANIX_MONITOR_SERVICES}
do
   if /usr/bin/systemctl is-enabled $i &> /dev/null
   then
      if ! /usr/bin/systemctl is-active $i &> /dev/null
      then
         if [ ${CRANIX_DEBUG^^} = "YES" ]; then
             echo "crx_check_services.sh start $i"
             /usr/bin/systemctl start $i
         else
             /usr/bin/systemctl start $i &> /dev/null
         fi
      fi
   fi
done

