#!/bin/bash
#
ME=$$
for i in  $( ps aux | grep "$1" |  gawk '{ if ($11 != "grep")  { print $2 } }' )
do
        if [ $i -ne $ME -a -d /proc/$i ]; then
                kill -9 $i
        fi
done
