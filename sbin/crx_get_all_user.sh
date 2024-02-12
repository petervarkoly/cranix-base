#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

/usr/sbin/crx_api.sh GET users/all | jq '.[] | .uid' | sed 's/"//g'

