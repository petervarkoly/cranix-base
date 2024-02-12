#!/bin/bash
# Check if a process with given command line is running
# (C) 2023 Peter Varkoly <pvarkoly@cephalix.eu Nuremberg Germany
ME=$$
if [ "${#1}" -lt 5  ]; then
        #Command to small
        exit 1
fi
if [[ "${1}" =~ ^/.*/.*  ]]; then
        #Command have to start with full path
        for i in  $( ps aux | grep "$1" |  gawk '{ if ($11 != "grep")  { print $2 } }' )
        do
                if [ $i -ne $ME -a -d /proc/$i ]; then
                        echo $i
                fi
        done
fi
