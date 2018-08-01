FROM centos:7

MAINTAINER "Björn Dieding" <bjoern@xrow.de>

ADD config /root/.ssh/config

ENV PATH=/opt/rh/rh-mariadb102/root/usr/bin:$PATH

RUN yum install -y centos-release-scl-rh && \
    INSTALL_PKGS="rsync tar gettext hostname bind-utils gzip rh-mariadb102  sshpass openssh openssh-clients" && \
    yum install -y --setopt=tsflags=nodocs $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all && \
    mkdir -p /backup && \
    chmod 777 /backup && \
    chmod -R 600 /root/.ssh/config

WORKDIR /backup

VOLUME ["/backup"]

ENTRYPOINT [ "/bin/sh", "-c" ]

CMD ["/bin/sh"]
