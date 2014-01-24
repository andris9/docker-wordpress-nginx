FROM ubuntu

# Forked from https://github.com/eugeneware/docker-wordpress-nginx
# MAINTAINER Eugene Ware <eugene@noblesamurai.com>

MAINTAINER Andris Reinman <andris@kreata.ee>

RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update
RUN apt-get -y upgrade

# Keep upstart from complaining
RUN dpkg-divert --local --rename --add /sbin/initctl
RUN ln -s /bin/true /sbin/initctl

# Basic Requirements
RUN apt-get -y install mysql-server mysql-client nginx php5-fpm php5-mysql php-apc pwgen python-setuptools curl git unzip openssh-server vim

# Wordpress Requirements
RUN apt-get -y install php5-curl php5-gd php5-intl php-pear php5-imagick php5-imap php5-mcrypt php5-memcache php5-ming php5-ps php5-pspell php5-recode php5-snmp php5-sqlite php5-tidy php5-xmlrpc php5-xsl libssh2-php

# Create directory for sshd and set locale
RUN mkdir -p /var/run/sshd && locale-gen en_US.utf8 && echo 'LC_ALL="en_US.utf8"' > /etc/environment

# mysql config
RUN sed -i -e "s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf
RUN sed -i -e "s/^syslog/log-error=error.log/" /etc/mysql/conf.d/mysqld_safe_syslog.cnf

# nginx config
RUN sed -i -e "s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf
# since 'upload_max_filesize = 10M' in /etc/php5/fpm/php.ini
RUN sed -i -e "s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 10m/;s/# server_tokens on;/server_tokens off;/" /etc/nginx/nginx.conf

RUN echo "daemon off;" >> /etc/nginx/nginx.conf

# php-fpm config
# "allow_url_fopen" must be "On" for WordPress auto upgrade
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g;s/upload_max_filesize = 2M/upload_max_filesize = 10M/;s/post_max_size = 8M/post_max_size = 10M/;s/expose_php = On/expose_php = Off/;s/max_execution_time = 30/max_execution_time = 60/;s/;ignore_user_abort = On/ignore_user_abort = Off/" /etc/php5/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf
RUN find /etc/php5/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;
RUN echo "php_admin_value[sendmail_path] = /usr/bin/sendmail -t -i" >> /etc/php5/fpm/pool.d/www.conf

# User for the blog
RUN useradd -s /bin/bash -d /home/wordpress -m wordpress && usermod -aG www-data wordpress

# nginx site conf
ADD ./nginx-site.conf /etc/nginx/sites-available/default

# Supervisor Config
RUN /usr/bin/easy_install supervisor
ADD ./supervisord.conf /etc/supervisord.conf

# Install Wordpress
ADD http://et.wordpress.org/latest-et.tar.gz /wordpress.tar.gz
RUN tar xvzf /wordpress.tar.gz -C /usr/share/nginx
RUN mv /usr/share/nginx/www/5* /usr/share/nginx/wordpress
RUN rm -rf /usr/share/nginx/www
RUN mv /usr/share/nginx/wordpress /usr/share/nginx/www
RUN chown -R wordpress:wordpress /usr/share/nginx/www

# Wordpress Initialization and Startup Script
ADD ./start.sh /start.sh
RUN chmod 755 /start.sh

# private expose
EXPOSE 22
EXPOSE 80

CMD ["/bin/bash", "/start.sh"]
