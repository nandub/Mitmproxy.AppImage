#!/usr/bin/env bash

docker build -t nandub/mitmproxy_appimage_ubuntu -f Dockerfile_test.ubuntu .
docker build -t nandub/mitmproxy_appimage_centos -f Dockerfile_test.centos .
docker build -t nandub/mitmproxy_appimage_ubuntu_lucid -f Dockerfile_test.ubuntu_lucid .
docker run -it --rm --entrypoint /bin/bash --cap-add SYS_ADMIN --cap-add MKNOD --device=/dev/fuse nandub/mitmproxy_appimage_ubuntu
docker run -it --rm --entrypoint /bin/bash --cap-add SYS_ADMIN --cap-add MKNOD --device=/dev/fuse nandub/mitmproxy_appimage_centos
docker run -it --rm --entrypoint /bin/bash --cap-add SYS_ADMIN --cap-add MKNOD --device=/dev/fuse nandub/mitmproxy_appimage_ubuntu_lucid
