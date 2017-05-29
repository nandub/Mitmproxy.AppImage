#!/usr/bin/env bash

set -e

DEBS="$(dirname "$(readlink -e "$0")")"

dpkg -i $DEBS/multiarch-support_2.15-0ubuntu10.18_amd64.deb
dpkg -i $DEBS/libffi6_3.0.11~rc1-5_amd64.deb
dpkg -i $DEBS/libffi-dev_3.0.11~rc1-5_amd64.deb
