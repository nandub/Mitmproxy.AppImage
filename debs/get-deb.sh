#!/bin/bash

PACKAGE=$1

URI=`apt-cache show $PACKAGE | grep "Filename:" | cut -f 2 -d " "`

wget http://archive.ubuntu.com/ubuntu/$URI -O /debs/$(basename $URI)
