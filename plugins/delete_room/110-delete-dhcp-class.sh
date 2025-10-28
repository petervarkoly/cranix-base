#!/bin/bash


id=""
name=""
description=""
startip=""
netmask=""
while read a
do
  b=${a/:*/}
  if [ "$a" != "${b}:" ]; then
     c=${a/$b: /}
  else
     c=""
  fi
  echo "$a, $b, $c"
  case "${b,,}" in
    id)
      id="${c}"
    ;;
    name)
      name="${c}"
    ;;
    description)
      description="${c}"
    ;;
    startip)
      startip="${c}"
    ;;
    netmask)
      netmask="${c}"
    ;;
  esac
done

cat << EOF | socat UNIX:/run/kea/kea4-ctrl-socket -,ignoreeof
{
    "command": "class-del",
    "arguments": {
        "name": "$name"
    }
}
EOF

