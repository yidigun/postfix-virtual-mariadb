ARG IMG_TAG=24.04
FROM docker.io/yidigun/ubuntu-base:${IMG_TAG}

ENV IMG_TAG=$IMG_TAG

RUN apt-get -y update && \
    DEBIAN_FRONTEND=noninteractive \
        apt-get -y install postfix postfix-mysql && \
    apt-get clean && \
    mkdir -p /etc/postfix/mariadb

COPY entrypoint.sh /
COPY etc/postfix/mariadb.template /etc/postfix/mariadb.template

EXPOSE 25/tcp 587/tcp

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "start" ]
