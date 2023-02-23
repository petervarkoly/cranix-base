#!/bin/bash
# Copyright (c) 2023 Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.

crx_api_text.sh GET users/byUid/$1/home 2>/dev/null
