#!/bin/sh

#Update system
apt update && apt upgrade -y

#Install basic dependencies
apt install -y \
ca-certificates bzip2 wget lsof \
git curl \
build-essential \
xsltproc \
uuid-dev \
zlib1g-dev libxslt1-dev libpcre3-dev libgd-dev libgeoip-dev

#Update CA Certificates and clean system
update-ca-certificates
apt autoremove -y
apt clean

#Backup Nginx configuration files
if [ -f "/usr/share/nginx/html/index.html" ];then
  mv -f /usr/share/nginx/html/index.html /usr/share/nginx/html/index.html_backup
fi
if [ -f "/usr/share/nginx/html/50x.html" ];then
  mv -f /usr/share/nginx/html/50x.html /usr/share/nginx/html/50x.html_backup
fi
if [ -d "/etc/nginx/html" ];then
  cd /etc/nginx
  mv -f html html_backup
  cd
fi
if [ -f "/etc/nginx/nginx.conf" ];then
  mv -f /etc/nginx/nginx.conf /etc/nginx/nginx.conf_backup
fi
if [ -d "/etc/nginx/conf.d/" ];then
  find /etc/nginx/conf.d -name "*.conf" | grep -q ".conf"
  if [ $? -eq 0 ];then
    cd /etc/nginx/conf.d
    rename -f "s/.conf/.conf_backup/" *.conf
    cd
  fi
fi
if [ -f "/etc/nginx/extra/pagespeed.conf" ];then
  mv -f /etc/nginx/extra/pagespeed.conf /etc/nginx/extra/pagespeed.conf_backup
fi
if [ -f "/etc/nginx/extra/cache_purge.conf" ];then
  mv -f /etc/nginx/extra/cache_purge.conf /etc/nginx/extra/cache_purge.conf_backup
fi

#Download OpenSSL latest version
openssl_download_page=$(curl -sS --fail https://www.openssl.org/source/)
openssl_download_refs=$(echo "$openssl_download_page" | grep -o 'openssl-[a-zA-Z0-9.]*[.]tar[.]gz')
openssl_versions_available=$(echo "$openssl_download_refs" | sed -e 's~^openssl-~~' -e 's~\.tar\.gz$~~')
openssl_latest_version=$(echo "$openssl_versions_available" | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -k 4,4 -g | tail -n 1)
OPENSSL_VERSION=$openssl_latest_version
echo "OpenSSL $OPENSSL_VERSION"
cd
wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz
tar -xvzf openssl-${OPENSSL_VERSION}.tar.gz
OPENSSL_DIR=$(find $HOME -name "*openssl-${OPENSSL_VERSION}*" -maxdepth 1 -mindepth 1 -type d)

#Build and upgrade OpenSSL
cd $OPENSSL_DIR
./config shared zlib-dynamic
make -j`nproc`
make install -j`nproc`
[ -f /usr/local/bin/openssl ] && rm -rf /usr/bin/openssl
[ -d /usr/local/include/openssl ] && rm -rf /usr/include/openssl
ln -s /usr/local/bin/openssl /usr/bin/openssl
ln -s /usr/local/include/openssl /usr/include/openssl
cp -rf /usr/local/ssl /etc/
grep -q '/usr/local/lib' /etc/ld.so.conf.d/* /etc/ld.so.conf
if [ $? -ne 0 ];then
  echo '/usr/local/lib' >> /etc/ld.so.conf.d/libc.conf
fi
ldconfig

#Download Jemalloc latest version
jemalloc_download_page=$(curl -sS --fail https://github.com/jemalloc/jemalloc/releases)
jemalloc_download_refs=$(echo "$jemalloc_download_page" | grep -o '/jemalloc-[a-zA-Z0-9.]*[.]tar[.]bz2')
jemalloc_versions_available=$(echo "$jemalloc_download_refs" | sed -e 's~^/jemalloc-~~' -e 's~\.tar\.bz2$~~')
jemalloc_latest_version=$(echo "$jemalloc_versions_available" | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -k 4,4 -g | tail -n 1)
JEMALLOC_VERSION=$jemalloc_latest_version
echo "Jemalloc $JEMALLOC_VERSION"
cd
wget https://github.com/jemalloc/jemalloc/releases/download/${JEMALLOC_VERSION}/jemalloc-${JEMALLOC_VERSION}.tar.bz2
tar -xjvf jemalloc-${JEMALLOC_VERSION}.tar.bz2
JEMALLOC_DIR=$(find $HOME -name "*jemalloc-${JEMALLOC_VERSION}*" -maxdepth 1 -mindepth 1 -type d)

#Build and install Jemalloc
cd $JEMALLOC_DIR
./configure
make -j`nproc`
make install -j`nproc`
grep -q '/usr/local/lib' /etc/ld.so.conf.d/* /etc/ld.so.conf
if [ $? -ne 0 ];then
  echo '/usr/local/lib' >> /etc/ld.so.conf.d/libc.conf
fi
ldconfig

#Download PageSpeed latest version
nps_download_page=$(curl -sS --fail https://github.com/apache/incubator-pagespeed-ngx/releases)
nps_download_refs=$(echo "$nps_download_page" | grep -o '/incubator-pagespeed-ngx/archive/v[a-zA-Z0-9.]*-stable[.]tar[.]gz')
nps_versions_available=$(echo "$nps_download_refs" | sed -e 's~^/incubator-pagespeed-ngx/archive/v~~' -e 's~\-stable\.tar\.gz$~~')
nps_latest_version=$(echo "$nps_versions_available" | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -k 4,4 -g | tail -n 1)
NPS_VERSION=$nps_latest_version
echo "PageSpeed $NPS_VERSION"
cd
wget https://github.com/apache/incubator-pagespeed-ngx/archive/v${NPS_VERSION}-stable.tar.gz
tar -xvzf v${NPS_VERSION}-stable.tar.gz
NPS_DIR=$(find $HOME -name "*incubator-pagespeed-ngx-${NPS_VERSION}-stable*" -maxdepth 1 -mindepth 1 -type d)
cd "$NPS_DIR"
[ -e scripts/format_binary_url.sh ] && PSOL_URL=$(scripts/format_binary_url.sh PSOL_BINARY_URL)
wget ${PSOL_URL}
tar -xzvf $(basename ${PSOL_URL})

#Download Cache-Purge latest version
ncp_download_page=$(curl -sS --fail https://github.com/FRiCKLE/ngx_cache_purge/releases)
ncp_download_refs=$(echo "$ncp_download_page" | grep -o '/ngx_cache_purge/archive/[a-zA-Z0-9.]*[.]tar[.]gz')
ncp_versions_available=$(echo "$ncp_download_refs" | sed -e 's~^/ngx_cache_purge/archive/~~' -e 's~\.tar\.gz$~~')
ncp_latest_version=$(echo "$ncp_versions_available" | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -k 4,4 -g | tail -n 1)
NCP_VERSION=$ncp_latest_version
echo "NCP $NCP_VERSION"
cd
wget https://github.com/FRiCKLE/ngx_cache_purge/archive/${NCP_VERSION}.tar.gz
tar -xvzf ${NCP_VERSION}.tar.gz
NCP_DIR=$(find $HOME -name "*ngx_cache_purge-${NCP_VERSION}*" -maxdepth 1 -mindepth 1 -type d)

#Download Brotli latest version
cd
git clone https://github.com/google/ngx_brotli
NB_DIR=$(find $HOME -name "*ngx_brotli*" -type d)
cd $NB_DIR
git submodule update --init

#Download Nginx latest version
nginx_download_page=$(curl -sS --fail https://nginx.org/en/download.html)
nginx_download_refs=$(echo "$nginx_download_page" | grep -o '/download/nginx-[a-zA-Z0-9.]*[.]tar[.]gz')
nginx_versions_available=$(echo "$nginx_download_refs" | sed -e 's~^/download/nginx-~~' -e 's~\.tar\.gz$~~')
nginx_latest_version=$(echo "$nginx_versions_available" | sort -t '.' -k 1,1 -k 2,2 -k 3,3 -k 4,4 -g | tail -n 1)
echo "Nginx $nginx_latest_version"
NGINX_VERSION=$nginx_latest_version
cd
wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
tar -xvzf nginx-${NGINX_VERSION}.tar.gz
NGINX_DIR=$(find $HOME -name "*nginx-${NGINX_VERSION}*" -maxdepth 1 -mindepth 1 -type d)

#Build and install Nginx
cd $NGINX_DIR
./configure --prefix=/etc/nginx \
  --sbin-path=/usr/sbin/nginx \
  --modules-path=/usr/lib/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --pid-path=/var/run/nginx.pid \
  --lock-path=/var/run/nginx.lock \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --user=nginx \
  --group=nginx \
  --with-http_ssl_module \
  --with-http_realip_module \
  --with-http_addition_module \
  --with-http_sub_module \
  --with-http_dav_module \
  --with-http_flv_module \
  --with-http_mp4_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_random_index_module \
  --with-http_secure_link_module \
  --with-http_stub_status_module \
  --with-http_auth_request_module \
  --with-http_xslt_module=dynamic \
  --with-http_image_filter_module=dynamic \
  --with-http_geoip_module=dynamic \
  --with-threads \
  --with-stream \
  --with-stream_ssl_module \
  --with-stream_ssl_preread_module \
  --with-stream_realip_module \
  --with-stream_geoip_module=dynamic \
  --with-http_slice_module \
  --with-mail \
  --with-mail_ssl_module \
  --with-compat \
  --with-file-aio \
  --with-http_v2_module \
  --with-ld-opt='-ljemalloc' \
  --add-module=$NPS_DIR \
  --add-module=$NCP_DIR \
  --add-module=$NB_DIR
make -j`nproc`
make install -j`nproc`

#Config Nginx
cd
groupadd -r nginx
useradd -r -d /var/cache/nginx -s /sbin/nologin -g nginx nginx
mkdir -p /var/cache/pagespeed
chown -R nginx:nginx /var/cache/pagespeed
mkdir -p /var/cache/nginx
mkdir -p /etc/nginx/conf.d
mkdir -p /etc/nginx/extra
mkdir -p /usr/share/nginx/html
chown -R nginx:nginx /usr/share/nginx/html
mv -f /etc/nginx/html/50x.html /usr/share/nginx/html/50x.html
mv -f /etc/nginx/html/index.html /usr/share/nginx/html/index.html
rm -rf /etc/nginx/html
cat > /etc/nginx/nginx.conf << \EOF
user  nginx;
worker_processes  1;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    brotli on;

    include /etc/nginx/conf.d/*.conf;
}
EOF
cp -rf /etc/nginx/nginx.conf /etc/nginx/nginx.conf.default
cat > /etc/nginx/conf.d/default.conf << \EOF
server {
    listen       80;
    server_name  localhost;

    #charset koi8-r;
    #access_log  /var/log/nginx/host.access.log  main;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    #error_page  404              /404.html;

    # redirect server error pages to the static page /50x.html
    #
    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }

    # proxy the PHP scripts to Apache listening on 127.0.0.1:80
    #
    #location ~ \.php$ {
    #    proxy_pass   http://127.0.0.1;
    #}

    # pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
    #
    #location ~ \.php$ {
    #    root           /usr/share/nginx/html;
    #    fastcgi_pass   127.0.0.1:9000;
    #    fastcgi_index  index.php;
    #    fastcgi_param  SCRIPT_FILENAME  /scripts$fastcgi_script_name;
    #    include        fastcgi_params;
    #}

    # deny access to .htaccess files, if Apache's document root
    # concurs with nginx's one
    #
    #location ~ /\.ht {
    #    deny  all;
    #}

    include /etc/nginx/extra/pagespeed.conf;
    include /etc/nginx/extra/cache_purge.conf;
}


    # another virtual host using mix of IP-, name-, and port-based configuration
    #
    #server {
    #    listen       8000;
    #    listen       somename:8080;
    #    server_name  somename  alias  another.alias;

    #    location / {
    #        root   /usr/share/nginx/html;
    #        index  index.html index.htm;
    #    }

    #    include /etc/nginx/extra/pagespeed.conf;
    #    include /etc/nginx/extra/cache_purge.conf;
    #}


    # HTTPS server
    #
    #server {
    #    listen       443 ssl;
    #    server_name  localhost;

    #    ssl_certificate      cert.pem;
    #    ssl_certificate_key  cert.key;

    #    ssl_session_cache    shared:SSL:1m;
    #    ssl_session_timeout  5m;

    #    ssl_ciphers  HIGH:!aNULL:!MD5;
    #    ssl_prefer_server_ciphers  on;

    #    location / {
    #        root   /usr/share/nginx/html;
    #        index  index.html index.htm;
    #    }

    #    include /etc/nginx/extra/pagespeed.conf;
    #    include /etc/nginx/extra/cache_purge.conf;
    #}
EOF
cp -rf /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.default
cat > /etc/nginx/extra/pagespeed.conf << \EOF
pagespeed on;

# Needs to exist and be writable by nginx.  Use tmpfs for best performance.
pagespeed FileCachePath /var/cache/pagespeed;

# Ensure requests for pagespeed optimized resources go to the pagespeed handler
# and no extraneous headers get set.
location ~ "\.pagespeed\.([a-z]\.)?[a-z]{2}\.[^.]{10}\.[^.]+" {
  add_header "" "";
}
location ~ "^/pagespeed_static/" { }
location ~ "^/ngx_pagespeed_beacon$" { }
EOF
cp -rf /etc/nginx/extra/pagespeed.conf /etc/nginx/extra/pagespeed.conf.default
cat > /etc/nginx/extra/cache_purge.conf << \EOF
#location ~ /purge(/.*) {
#    allow 127.0.0.1;
#    deny all;
#    proxy_cache_purge tmpcache $1$is_args$args;
#}
EOF
cp -rf /etc/nginx/extra/cache_purge.conf /etc/nginx/extra/cache_purge.conf.default

#Start Nginx
if [ ! -f "/etc/systemd/system/nginx.service" ];then
cat > /etc/systemd/system/nginx.service << \EOF
[Unit]
Description=nginx
After=network.target

[Service]
Type=forking
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/usr/sbin/nginx -s stop
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
fi
systemctl daemon-reload
systemctl enable nginx
systemctl start nginx
systemctl reload nginx

#Remove temporary files
rm -rf $HOME/openssl-${OPENSSL_VERSION}.tar.gz \
  $HOME/openssl-${OPENSSL_VERSION}.tar.gz.1 \
  ${OPENSSL_DIR} \
  $HOME/jemalloc-${JEMALLOC_VERSION}.tar.bz2 \
  $HOME/jemalloc-${JEMALLOC_VERSION}.tar.bz2.1 \
  ${JEMALLOC_DIR} \
  $HOME/v${NPS_VERSION}-stable.tar.gz \
  $HOME/v${NPS_VERSION}-stable.tar.gz.1 \
  $NPS_DIR \
  $HOME/${NCP_VERSION}.tar.gz \
  $HOME/${NCP_VERSION}.tar.gz.1 \
  ${NCP_DIR} \
  ${NB_DIR} \
  $HOME/nginx-${NGINX_VERSION}.tar.gz \
  $HOME/nginx-${NGINX_VERSION}.tar.gz.1 \
  ${NGINX_DIR} \
  /usr/lib/nginx/modules/ngx_http_geoip_module.so.old \
  /usr/lib/nginx/modules/ngx_http_image_filter_module.so.old \
  /usr/lib/nginx/modules/ngx_http_xslt_filter_module.so.old \
  /usr/lib/nginx/modules/ngx_stream_geoip_module.so.old \
  /usr/sbin/nginx.old

#Check Nginx status
openssl version | grep -q $OPENSSL_VERSION
if [ $? -eq 0 ];then
  echo -e "\033[92m OpenSSL ${OPENSSL_VERSION} has been upgraded and working. \033[0m"
else
  echo -e "\033[91m OpenSSL upgrade failed. \033[0m"
fi
systemctl status nginx | grep -q "active (running)"
if [ $? -eq 0 ];then
  echo -e "\033[92m Nginx ${NGINX_VERSION} has been installed and working. \033[0m"
  lsof -n | grep -q "jemalloc"
  if [ $? -eq 0 ];then
    echo -e "\033[92m Jemalloc ${JEMALLOC_VERSION} has been installed and load. \033[0m"
  else
    echo -e "\033[91m Jemalloc load failed. \033[0m"
  fi
  curl -s -I http://localhost | grep -q "Page-Speed"
  if [ $? -eq 0 ];then
    echo -e "\033[92m PageSpeed ${NPS_VERSION} has been built and load. \033[0m"
  else
    echo -e "\033[91m PageSpeed load failed. \033[0m"
  fi
  nginx -V | grep -q "ngx_cache_purge"
  if [ $? -eq 0 ];then
    echo -e "\033[92m Cache-Purge ${NCP_VERSION} has been built. \033[0m"
  else
    echo -e "\033[91m Cache-Purge build failed. \033[0m"
  fi
  curl -s -I -H "Accept-Encoding: br" http://localhost | grep -q "br"
  if [ $? -eq 0 ];then
    echo -e "\033[92m The latest version Brotli has been built and load. \033[0m"
  else
    echo -e "\033[91m Brotli load failed. \033[0m"
  fi
else
  echo -e "\033[91m Nginx start failed. \033[0m"
fi

#Restore Nginx configuration files
if [ -f "/usr/share/nginx/html/index.html_backup" ];then
  mv -f /usr/share/nginx/html/index.html_backup /usr/share/nginx/html/index.html
fi
if [ -f "/usr/share/nginx/html/50x.html_backup" ];then
  mv -f /usr/share/nginx/html/50x.html_backup /usr/share/nginx/html/50x.html
fi
if [ -d "/etc/nginx/html_backup" ];then
  cd /etc/nginx
  mv -f html_backup html
  cd
fi
if [ -f "/etc/nginx/nginx.conf_backup" ];then
  mv -f /etc/nginx/nginx.conf_backup /etc/nginx/nginx.conf
fi
find /etc/nginx/conf.d -name "*.conf_backup" | grep -q ".conf_backup"
if [ $? -eq 0 ];then
  cd /etc/nginx/conf.d
  rm -rf default.conf
  rename -f "s/.conf_backup/.conf/" *.conf_backup
  cd
fi
if [ -f "/etc/nginx/extra/pagespeed.conf_backup" ];then
  mv -f /etc/nginx/extra/pagespeed.conf_backup /etc/nginx/extra/pagespeed.conf
fi
if [ -f "/etc/nginx/extra/cache_purge.conf_backup" ];then
  mv -f /etc/nginx/extra/cache_purge.conf_backup /etc/nginx/extra/cache_purge.conf
fi
systemctl reload nginx
echo -e "\033[93m Please enable PageSpeed in every server block of the Nginx configuration,refer to the default configuration file. \033[0m"
echo -e "\033[94m /etc/nginx/conf.d/default.conf.default \033[0m"
echo -e "\033[94m /etc/nginx/extra/pagespeed.conf.default \033[0m"
echo -e "\033[93m Please config Cache-Purge in every server block of the Nginx configuration,refer to the default configuration file. \033[0m"
echo -e "\033[94m /etc/nginx/conf.d/default.conf.default \033[0m"
echo -e "\033[94m /etc/nginx/extra/cache_purge.conf.default \033[0m"
echo -e "\033[93m Please enable Brotli in http block of the Nginx configuration,refer to the default configuration file. \033[0m"
echo -e "\033[94m /etc/nginx/nginx.conf.default \033[0m"
