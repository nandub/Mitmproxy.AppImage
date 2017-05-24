FROM ubuntu:14.04
LABEL maintainer "Fernando Ortiz <nandub@nandub.info>"

WORKDIR /root

RUN mkdir /root/linux
COPY ./linux /root/linux
COPY ./appimage.sh /root
RUN chmod +x /root/appimage.sh

VOLUME image

ENTRYPOINT ["/bin/bash"]

CMD ["/root/appimage.sh"]
