#!/bin/bash

set -e

NWAF_VER=$(dpkg -l | grep nwaf-dyn | awk '{print$3}')
NWAF_VER_FILE=/etc/nginx/nwaf-dyn-version

UI_DIR=/etc/nginx-ui

create_configs() {
  local NGINX_CONF
  NGINX_CONF=/etc/nginx/nginx.conf
  sed -i '1s|^|load_module /etc/nginx/modules/ngx_http_waf_module.so;|' $NGINX_CONF
  sed -i -E 's/^(\s*error_log)\s+.*;\s*$/\1\t\/dev\/stderr\tnotice;/; s/^(\s*access_log)\s+.*;\s*$/\1\t\/dev\/stdout\tmain;/' $NGINX_CONF
  sed -i 's/.*worker_processes.*;/worker_processes auto;/' $NGINX_CONF
  gzpos=$(sed -n '/gzip\s\s*on;/=' $NGINX_CONF)
  sed -i "${gzpos}a\\\n    ##\n    # Nemesida WAF\n    ##\n\n    ## Fix: request body too large\n    client_body_buffer_size 25M;\n\n    include /etc/nginx/nwaf/conf/global/*.conf;\n    include /etc/nginx/nwaf/conf/vhosts/*.conf;" $NGINX_CONF
  sed -i '/^http {/,/^}/!b;/^}/i\    include /etc/nginx/sites-enabled/*;' $NGINX_CONF
  dpkg -l | grep nwaf-dyn | awk '{print$3}' > $NWAF_VER_FILE
}

mkdir -p /etc/nginx
if [[ "$(ls -A /etc/nginx)" = "" ]]; then
  echo "Initialing Nginx config dir..."

  cp -rp /etc/nginx-orig/* /etc/nginx/
  mkdir -p /etc/nginx/sites-{enabled,available}
  create_configs

  echo "Nginx config dir is done"
fi

mkdir -p $UI_DIR
if [[ ! -f "${UI_DIR}/app.ini" ]]; then
  echo "Initialing Nginx UI config file..."

  cat > "${UI_DIR}/app.ini" << EOF
[server]
RunMode = release
HttpPort = 9000
HTTPChallengePort = 9180
EOF

  echo "Nginx UI config file is done"
fi

[[ -f /etc/machine-id ]] || /usr/bin/dbus-uuidgen > /etc/machine-id
[[ $(cat $NWAF_VER_FILE) != $NWAF_VER ]] && echo "New version ${NWAF_VER}! Need to upgdate configs dir!"

epmd -daemon
for SVC in rabbitmq-server nwaf_update nginx-ui cron; do service $SVC start; done

exec "$@"
