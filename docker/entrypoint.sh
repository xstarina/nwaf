#!/bin/bash

set -e

NWAF_VER=$(dpkg -l | grep nwaf-dyn | awk '{print$3}')
NWAF_VER_FILE=/etc/nginx/nwaf-dyn-version

create_configs() {
  local NGINX_CONF
  NGINX_CONF=/etc/nginx/nginx.conf
  sed -i '1s|^|load_module /etc/nginx/modules/ngx_http_waf_module.so;|' $NGINX_CONF
  sed -i 's/.*worker_processes.*;/worker_processes auto;/' $NGINX_CONF
  gzpos=$(sed -n '/gzip  on;/=' $NGINX_CONF)
  sed -i "${gzpos}a\\\n    ##\n    # Nemesida WAF\n    ##\n\n    ## Fix: request body too large\n    client_body_buffer_size 25M;\n\n    include /etc/nginx/nwaf/conf/global/*.conf;\n    include /etc/nginx/nwaf/conf/vhosts/*.conf;\n" $NGINX_CONF
  dpkg -l | grep nwaf-dyn | awk '{print$3}' > $NWAF_VER_FILE
}

mkdir -p /etc/nginx
if [ "$(ls -A /etc/nginx)" = "" ]; then
  echo "Initialing Nginx config dir..."

  cp -rp /etc/nginx-orig/* /etc/nginx/
  mkdir -p /etc/nginx/sites-{enabled,available}
  create_configs

  echo "Nginx config dir is done"
fi

[[ $(cat $NWAF_VER_FILE) != $NWAF_VER ]] && echo "New version ${NWAF_VER}! Need to upgdate configs dir!"

epmd -daemon
service rabbitmq-server start
service nwaf_update start
nginx-ui -config /usr/local/etc/nginx-ui/app.ini &

exec "$@"
