#!/bin/bash

set -e

NWAF_VER=$(dpkg -l | grep nwaf-dyn | awk '{print$3}')
NWAF_VER_FILE=/etc/nginx/nwaf-dyn-version

NGINX_DIR=/etc/nginx
UI_DIR=/etc/nginx-ui
NGINX_CONF=${NGINX_DIR}/nginx.conf

create_configs() {
  local NWAF_CONF=${NGINX_DIR}/nwaf-custom.conf

  sed -i "1s|^|load_module ${NGINX_DIR}/modules/ngx_http_waf_module.so;|" ${NGINX_CONF}
  sed -i "s/.*worker_processes.*;/worker_processes auto;/" ${NGINX_CONF}
  gzpos=$(sed -n '/gzip\s\s*on;/=' ${NGINX_CONF})
  sed -i "${gzpos}a\\\n    ##\n    # Nemesida WAF\n    ##\n\n    ## Fix: request body too large\n    client_body_buffer_size 25M;\n\n    ## Custom Nwaf settings\n    include ${NWAF_CONF};\n    include ${NGINX_DIR}/nwaf/conf/global/*.conf;\n    include ${NGINX_DIR}/nwaf/conf/vhosts/*.conf;" ${NGINX_CONF}
  sed -i "/^http {/,/^}/!b;/^}/i\    include ${NGINX_DIR}/sites-enabled/*;\n    include ${NGINX_DIR}/streams-enabled/*;" ${NGINX_CONF}

  cat > ${NWAF_CONF} << EOF
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
}

mkdir -p ${NGINX_DIR}
if [[ "$(ls -A ${NGINX_DIR})" = "" ]]; then
  echo 'Initialing Nginx config dir...'

  cp -rp /etc/nginx-orig/* ${NGINX_DIR}/
  mkdir -p ${NGINX_DIR}/{sites,streams}-{enabled,available}
  create_configs

  echo 'Nginx config dir is done'
fi

mkdir -p ${UI_DIR}
if [[ ! -f "${UI_DIR}/app.ini" ]]; then
  echo 'Initialing Nginx UI config file...'

  cat > ${UI_DIR}/app.ini << EOF
[server]
RunMode = release
HttpPort = 9000
HTTPChallengePort = 9180

[nginx]
AccessLogPath = /var/log/nginx/access.log
ErrorLogPath = /var/log/nginx/error.log
RestartCmd = /usr/bin/supervisorctl restart nginx
EOF

  echo 'Nginx UI config file is done'
fi

if grep -qF '[nginx_log]' ${UI_DIR}/app.ini; then
  echo "Migrating ${UI_DIR}/app.ini to a new format..."
  sed -i.bak "s/\[nginx_log\]/[nginx]\nRestartCmd = \/usr\/bin\/supervisorctl restart nginx/" ${UI_DIR}/app.ini
  echo 'Migrating done'
fi

if ! grep -qF '/streams-enabled/*;' ${NGINX_CONF}; then
  echo "Adding Nginx streams to ${NGINX_CONF}..."
  mkdir -p ${NGINX_DIR}/streams-{enabled,available}
  sed -i.bak "/^http {/,/^}/!b;/^}/i\    include ${NGINX_DIR}/streams-enabled/*;" ${NGINX_CONF}
  echo 'Streams done'
fi

[[ ! -f ${NWAF_VER_FILE} ]] && echo ${NWAF_VER} > ${NWAF_VER_FILE}
[[ ! -f /etc/machine-id ]] && /usr/bin/dbus-uuidgen > /etc/machine-id

if [[ $(cat ${NWAF_VER_FILE}) != ${NWAF_VER} ]]; then
  echo "New version ${NWAF_VER}! Need to upgdate configs dir!"
  echo ${NWAF_VER} > ${NWAF_VER_FILE}
fi
rm -rf /etc/rabbitmq/*

for L in access error; do
  LOG=/var/log/nginx/${L}.log
  [[ -L $LOG ]] && rm -f $LOG
done

exec "$@"
