FROM nginx:latest

RUN set -x && export DEBIAN_FRONTEND=noninteractive \
  && apt-get update && apt-get install apt-utils && apt-get upgrade -y \
  && apt-get install apt-transport-https gnupg2 curl procps python3 python3-venv python3-pip python3-dev python3-setuptools librabbitmq4 libcurl3-gnutls libcurl4-openssl-dev libc6-dev gcc rabbitmq-server libmaxminddb0 g++ memcached jq dbus -y \
  && /bin/sh -c python3 -m pip install --upgrade pip

RUN set -x && export DEBIAN_FRONTEND=noninteractive \
  && echo "deb https://nemesida-security.com/repo/nw/debian bullseye non-free" > /etc/apt/sources.list.d/NemesidaWAF.list \
  && curl -s https://nemesida-security.com/repo/nw/gpg.key | gpg --no-default-keyring --keyring gnupg-ring:/etc/apt/trusted.gpg.d/trusted.gpg --import \
  && chmod 644 /etc/apt/trusted.gpg.d/trusted.gpg \
  && apt-get update && apt-get install nwaf-dyn-1.22 -y

COPY /nginx-ui /nginx-ui
RUN bash /nginx-ui/get-latest.sh

