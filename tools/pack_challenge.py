#!/usr/bin/python3
#
# Copyright (C) Peter Varkoly <pvarkoly@cephalix.eu> Nuremberg, Germany.  All rights reserved.
#

from xhtml2pdf import pisa             # import python module
import sys
import csv
import os
from html import escape

challenge_dir = sys.argv[1]
date = challenge_dir.split('/')[-1:][0]
def convertHtmlToPdf(sourceHtml, outputFilename):
    with open(outputFilename, "w+b") as resultFile:
        # convert HTML to PDF
        pisaStatus = pisa.CreatePDF(
            sourceHtml,                # the HTML to convert
            dest=resultFile)           # file handle to recieve result

for file_name in os.listdir(challenge_dir):
    if file_name.endswith('.html'):
        with open(challenge_dir + '/' +file_name,'r') as f:
            sourceHtml = f.read()
            outputFilename = challenge_dir + '/' + file_name.replace('.html','.pdf')
            convertHtmlToPdf(sourceHtml, outputFilename)

os.system('cd {0}; zip {1}.zip *.pdf &> /dev/null'.format(challenge_dir,date))
print('{0}/{1}.zip'.format(challenge_dir,date))
