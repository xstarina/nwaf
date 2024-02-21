#!/bin/bash

set -e

NWAF_VER=$(dpkg -l | grep nwaf-dyn | awk '{print$3}')
NWAF_VER_FILE=/etc/nginx/nwaf-dyn-version

UI_DIR=/etc/nginx-ui

create_configs() {
  local NGINX_CONF=/etc/nginx/nginx.conf
  local NWAF_CONF=/etc/nginx/nwaf-custom.conf

  sed -i '1s|^|load_module /etc/nginx/modules/ngx_http_waf_module.so;|' $NGINX_CONF
  # sed -i -E 's/^(\s*error_log)\s+.*;\s*$/\1\t\/dev\/stderr\tnotice;/; s/^(\s*access_log)\s+.*;\s*$/\1\t\/dev\/stdout\tmain;/' $NGINX_CONF
  sed -i 's/.*worker_processes.*;/worker_processes auto;/' $NGINX_CONF
  gzpos=$(sed -n '/gzip\s\s*on;/=' $NGINX_CONF)
  sed -i "${gzpos}a\\\n    ##\n    # Nemesida WAF\n    ##\n\n    ## Fix: request body too large\n    client_body_buffer_size 25M;\n\n    ## Custom Nwaf settings\n    include $NWAF_CONF;\n    include /etc/nginx/nwaf/conf/global/*.conf;\n    include /etc/nginx/nwaf/conf/vhosts/*.conf;" $NGINX_CONF
  sed -i '/^http {/,/^}/!b;/^}/i\    include /etc/nginx/sites-enabled/*;' $NGINX_CONF

  cat > $NWAF_CONF << EOF
# this is the internal Docker DNS, cache only for 30s
resolver 127.0.0.11 valid=30s;

# Exclude request body processing for specific URL
# nwaf_body_exclude www.site.com/fld1/fld2;

# Add client's IP to the whitelist
# nwaf_ip_wl 10.10.15.15;

# Ban settings
nwaf_limit rate=5r/m block_time=600;
# nwaf_limit rate=5r/m block_time=0 domain=example.com;
EOF

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

[nginx_log]
AccessLogPath = /var/log/nginx/access.log
ErrorLogPath = /var/log/nginx/error.log
EOF

  echo "Nginx UI config file is done"
fi

[[ -f /etc/machine-id ]] || /usr/bin/dbus-uuidgen > /etc/machine-id
[[ $(cat $NWAF_VER_FILE) != $NWAF_VER ]] && echo "New version ${NWAF_VER}! Need to upgdate configs dir!"

rm -rf /etc/rabbitmq/*

exec "$@"
