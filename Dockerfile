FROM nginx:1.24

ENV BUILD_VER=230920-01
ENV NWAF_PKG=nwaf-dyn-1.24
ENV DEBIAN_FRONTEND=noninteractive

RUN set -x \
  && apt-get update && apt-get upgrade -y \
  && apt-get install apt-utils apt-transport-https gnupg2 curl procps dbus -y

RUN set -x \
  && echo "deb https://nemesida-security.com/repo/nw/debian bullseye non-free" > /etc/apt/sources.list.d/NemesidaWAF.list \
  && curl -s https://nemesida-security.com/repo/nw/gpg.key | gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/trusted.gpg --import \
  && chmod 644 /etc/apt/trusted.gpg.d/trusted.gpg \
  && apt-get update \
  && apt-get install $(apt-cache depends $NWAF_PKG | awk '/Depends:/{print$2}') -y \
  && python3 -m pip install --upgrade pip

RUN set -x && apt-get install $NWAF_PKG -y
RUN set -x && mv /etc/nginx /etc/nginx-orig

COPY docker/nginx-ui/get-latest.sh /nginx-ui/
RUN set -x && bash /nginx-ui/get-latest.sh

COPY docker /
RUN set -x && chmod +x /etc/init.d/*

EXPOSE 80 443 9000

ENTRYPOINT ["bash", "/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
