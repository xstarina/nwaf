FROM nginx:1.24

RUN set -ex; \
    apt-get update && apt-get upgrade -y; \
    apt-get install supervisor apt-utils apt-transport-https gnupg2 curl procps dbus -y; \
    rm -rf /var/lib/apt/lists/*

ARG DEBIAN_FRONTEND=noninteractive
ENV BUILD_VER=240221-01
ENV NWAF_PKG=nwaf-dyn-1.24

RUN set -ex; \
    echo "deb https://nemesida-security.com/repo/nw/debian bullseye non-free" > /etc/apt/sources.list.d/NemesidaWAF.list; \
    curl -s https://nemesida-security.com/repo/nw/gpg.key | gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/trusted.gpg --import; \
    chmod 644 /etc/apt/trusted.gpg.d/trusted.gpg; \
    apt-get update; \
    apt-get install $(apt-cache depends $NWAF_PKG | awk '/Depends:/{print$2}') $NWAF_PKG -y; \
    python3 -m pip install --upgrade pip; \
    mv /etc/nginx /etc/nginx-orig; \
    rm -rf /var/lib/apt/lists/*

RUN set -ex; \
    mkdir -p /run/systemd/system; \
    curl -L -s https://raw.githubusercontent.com/0xJacky/nginx-ui/master/install.sh -o /tmp/install.sh; \
    bash /tmp/install.sh install; \
    rm -f /tmp/install.sh

COPY ./docker/ /

EXPOSE 80 443 9000

ENTRYPOINT ["bash", "/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
