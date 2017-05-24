#!/usr/bin/env bash

docker build -t nandub/mitmproxy_appimage_ubuntu -f Dockerfile.ubuntu .
docker build -t nandub/mitmproxy_appimage_centos -f Dockerfile.centos .
docker run -it --entrypoint /bin/bash --cap-add SYS_ADMIN --cap-add MKNOD --device=/dev/fuse nandub/mitmproxy_appimage_ubuntu
docker run -it --entrypoint /bin/bash --cap-add SYS_ADMIN --cap-add MKNOD --device=/dev/fuse nandub/mitmproxy_appimage_centos
