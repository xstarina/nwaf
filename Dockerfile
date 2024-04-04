FROM nginx:1.24-bullseye

RUN set -ex; \
    apt-get update && apt-get upgrade -y; \
    apt-get install supervisor apt-utils apt-transport-https gnupg2 curl procps dbus -y; \
    rm -rf /var/lib/apt/lists/*

ARG DEBIAN_FRONTEND=noninteractive
ENV BUILD_VER=240402-01
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
    rm -rf /run/systemd/system; \
    rm -f /tmp/install.sh

COPY ./docker/ /

EXPOSE 80 443 9000

LABEL   maintainer=starina \
        description="Nginx + Nwaf + Nginx UI as a Docker container" \
        org.opencontainers.image.vendor=starina \
        org.opencontainers.image.source=https://github.com/xstarina/nwaf \
        org.opencontainers.image.title=nwaf \
        org.opencontainers.image.description="Nginx + Nginx UI as a Docker container" \
        org.opencontainers.image.licenses=MIT

ENTRYPOINT ["bash", "/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]

# edit 240404-02
