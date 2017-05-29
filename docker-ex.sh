#!/usr/bin/env bash

if [ "x$1" == "xfuse" ]; then
  fuse="--cap-add SYS_ADMIN --cap-add MKNOD --device=/dev/fuse"
  shift
fi
docker run -it --entrypoint $SHELL $fuse -v $PWD/images:/images -v $PWD/debs:/debs $1
