#!/usr/bin/env bash

echo deb http://old-releases.ubuntu.com/ubuntu lucid main universe > /etc/apt/sources.list
echo deb http://old-releases.ubuntu.com/ubuntu lucid-updates main universe >> /etc/apt/sources.list
echo deb http://old-releases.ubuntu.com/ubuntu lucid-security main universe >> /etc/apt/sources.list
