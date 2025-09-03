#!/usr/bin/python3
#
# Copyright (C) Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
#

import sys
import csv
import os
from html import escape

challenge_dir = sys.argv[1]
date = challenge_dir.split('/')[-1:][0]

for file_name in os.listdir(challenge_dir):
    if file_name.endswith('.html'):
        outputFilename = challenge_dir + '/' + file_name.replace('.html','.pdf')
        os.system(f"/usr/bin/htmldoc --no-title --no-toc --charset utf-8 -f {challenge_dir}/{fileName} {outputFilename}")

os.system('cd {0}; zip {1}.zip *.pdf &> /dev/null'.format(challenge_dir,date))
print('{0}/{1}.zip'.format(challenge_dir,date))
