FROM ubuntu:14.04
 
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update
RUN locale-gen en_US en_US.UTF-8
ENV LANG en_US.UTF-8
ENV TERM xterm
RUN echo "export PS1='\e[1;31m\]\u@\h:\w\\$\[\e[0m\] '" >> /root/.bashrc

# Runit
RUN apt-get install -y runit 
CMD export > /etc/envvars && /usr/sbin/runsvdir-start
RUN echo 'export > /etc/envvars' >> /root/.bashrc

# Utilities
RUN apt-get install -y vim less net-tools inetutils-ping wget curl git telnet nmap socat dnsutils netcat tree htop unzip sudo software-properties-common jq psmisc

#RUN wget -O dreamfactory.run https://downloads.bitnami.com/files/stacks/dreamfactory/2.1.0-4/bitnami-dreamfactory-2.1.0-4-linux-x64-installer.run

# Nginx
RUN apt-get install -y nginx

# MySql
RUN apt-get install -y mysql-server mysql-client

# MongoDB
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
    echo "deb http://repo.mongodb.org/apt/ubuntu "$(lsb_release -sc)"/mongodb-org/3.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.0.list && \
    apt-get update
RUN apt-get install -y mongodb-org

# PHP
RUN apt-get install -y php5 php5-common php5-cli php5-curl php5-json php5-mcrypt php5-gd php5-mysql php5-sqlite php-pear php5-dev
RUN php5enmod mcrypt
RUN apt-get install -y php5-fpm
RUN sed -i "s|;cgi.fix_pathinfo=1|cgi.fix_pathinfo=0|" /etc/php5/fpm/php.ini

# Mongo
RUN apt-get install -y libpcre3-dev libsasl2-dev
RUN pecl install mongo 
RUN echo "extension=mongo.so" > /etc/php5/mods-available/mongo.ini
RUN php5enmod mongo 

# V8js
RUN cd /tmp && \
    git clone --depth=1 https://chromium.googlesource.com/chromium/tools/depot_tools.git && \
    export PATH=`pwd`/depot_tools:"$PATH" && \
    fetch v8 && \
    cd v8 && \
    gclient sync && \
    make native library=shared snapshot=off -j8 && \
    mkdir -p /usr/lib /usr/include && \
    cp out/native/lib.target/lib*.so /usr/lib/ && \
    cp -R include/* /usr/include && \
    echo "create /usr/lib/libv8_libplatform.a\naddlib out/native/obj.target/tools/gyp/libv8_libplatform.a\nsave\nend" | ar -M && \
    cp out/native/lib.target/lib*.so /usr/lib/x86_64-linux-gnu/ && \
    rm -rf /tmp/*
RUN apt-get install -y g++ cpp
RUN pecl install v8js-0.4.1
RUN echo "extension=v8js.so" > /etc/php5/mods-available/v8js.ini
RUN php5enmod v8js

# Composer
RUN php -r "readfile('https://getcomposer.org/installer');" > composer-setup.php && \
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    php -r "unlink('composer-setup.php');"

# Dreamfactory
RUN git clone --depth=1 https://github.com/dreamfactorysoftware/dreamfactory.git /df2
RUN cd /df2 && \
    composer install --no-dev
RUN chown -R www-data:www-data /df2/storage/ /df2/bootstrap/cache/ && \
    chmod -R 2775 /df2/storage/ /df2/bootstrap/cache/

# Config
COPY .env /df2/
COPY default /etc/nginx/sites-available/
COPY mongod.conf /etc/mongod.conf

# Add runit services
COPY sv /etc/service 

# MySql
COPY mysql.ddl /
RUN mysqld_safe & mysqladmin --wait=5 ping && \
    mysql < mysql.ddl && \
    mysqladmin shutdown
