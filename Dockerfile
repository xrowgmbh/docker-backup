FROM centos:7

MAINTAINER "Björn Dieding" <bjoern@xrow.de>

ADD config /root/.ssh/config
ADD sync.sh /sync.sh
ENV PATH=/opt/rh/rh-mariadb102/root/usr/bin:$PATH

RUN yum install -y centos-release-scl-rh && \
    INSTALL_PKGS="rsync tar gettext hostname bind-utils gzip rh-mariadb102  sshpass openssh openssh-clients epel-release" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    yum install -y jq && \
    rpm -V $INSTALL_PKGS && \
    yum clean all && \
    mkdir -p /backup && \
    chmod 777 /backup && \
    chmod -R 600 /root/.ssh/config && \
    chmod 777 /sync.sh

WORKDIR /backup

VOLUME ["/backup"]
USER root

ENTRYPOINT [ "/bin/bash", "/sync.sh"]
