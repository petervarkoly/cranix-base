#!/bin/bash
/usr/bin/doveadm quota get -u $1  2>/dev/null | gawk '/STORAGE/ { print int($4/1024)" "int($5/1024) }'

