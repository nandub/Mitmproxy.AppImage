#!/usr/bin/env bash

docker build -t nandub/mitmproxy_appimage .
docker run -it -d --name mitmproxy -v $(pwd)/images:/image --cap-add SYS_ADMIN --cap-add MKNOD --device=/dev/fuse nandub/mitmproxy_appimage
docker ps
