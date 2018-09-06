#!/bin/bash
SSH=`which ssh`
echo "start ${SSH}"
echo "ssh -v hq2mysql1.sfdev.businesswire.com \"ls -l\""
${SSH} -v hq2mysql1.sfdev.businesswire.com "ls -l"
echo "end"
