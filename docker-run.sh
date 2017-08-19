#!/usr/bin/env bash

docker build -t nandub/mitmproxy_appimage -f Dockerfile.ubuntu_lucid .
docker run -it --rm -d --name mitmproxy -v $(pwd)/images:/image -v$(pwd)/debs:/debs --cap-add SYS_ADMIN --cap-add MKNOD --device=/dev/fuse nandub/mitmproxy_appimage
docker ps
