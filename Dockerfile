FROM ubuntu

# Forked from https://github.com/eugeneware/docker-wordpress-nginx
# MAINTAINER Eugene Ware <eugene@noblesamurai.com>

MAINTAINER Andris Reinman <andris@kreata.ee>

RUN echo "deb http://archive.ubuntu.com/ubuntu precise main universe" > /etc/apt/sources.list
RUN apt-get update
RUN apt-get -y upgrade

# Keep upstart from complaining
# RUN dpkg-divert --local --rename --add /sbin/initctl
# RUN ln -s /bin/true /sbin/initctl

# Basic Requirements
# RUN apt-get -y install mysql-server mysql-client nginx php5-fpm php5-mysql php-apc pwgen python-setuptools curl git unzip openssh-server vim
RUN apt-get -y install mysql-client nginx php5-fpm php5-mysql php-apc pwgen python-setuptools curl git unzip openssh-server vim

# Wordpress Requirements
RUN apt-get -y install php5-curl php5-gd php5-intl php-pear php5-imagick php5-imap php5-mcrypt php5-memcache php5-ming php5-ps php5-pspell php5-recode php5-snmp php5-sqlite php5-tidy php5-xmlrpc php5-xsl libssh2-php

# Email requirements
RUN apt-get install -y python-software-properties software-properties-common python build-essential && add-apt-repository -y ppa:chris-lea/node.js && apt-get update && apt-get install -y nodejs
RUN npm install --unsafe-perm -g wp-sendmail@0.1.5

ADD ./wp-sendmail.js /etc/wp-sendmail.js

# Create directory for sshd and set locale
RUN mkdir -p /var/run/sshd && locale-gen en_US.utf8 && echo 'LC_ALL="en_US.utf8"' >> /etc/environment

# mysql config
# RUN sed -i -e "s/^bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/mysql/my.cnf
# Uncomment this line if you want mysql logs to a log file instead of syslog
# RUN sed -i -e "s/^syslog/log-error=error.log/" /etc/mysql/conf.d/mysqld_safe_syslog.cnf

# nginx config
RUN sed -i -e "s/keepalive_timeout\s*65/keepalive_timeout 2/" /etc/nginx/nginx.conf
# since 'upload_max_filesize = 10M' in /etc/php5/fpm/php.ini
RUN sed -i -e "s/keepalive_timeout 2/keepalive_timeout 2;\n\tclient_max_body_size 10m/;s/# server_tokens on;/server_tokens off;/" /etc/nginx/nginx.conf

RUN echo "daemon off;" >> /etc/nginx/nginx.conf

# php-fpm config
# "allow_url_fopen" must be "On" for WordPress auto upgrade
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g;s/upload_max_filesize = 2M/upload_max_filesize = 10M/;s/post_max_size = 8M/post_max_size = 10M/;s/expose_php = On/expose_php = Off/;s/max_execution_time = 30/max_execution_time = 60/;s/;ignore_user_abort = On/ignore_user_abort = Off/;s/disable_functions = /disable_functions = php_uname, getmyuid, getmypid, passthru, leak, listen, diskfreespace, tmpfile, link, ignore_user_abort, shell_exec, dl, set_time_limit, exec, system, highlight_file, source, show_source, fpaththru, virtual, posix_ctermid, posix_getcwd, posix_getegid, posix_geteuid, posix_getgid, posix_getgrgid, posix_getgrnam, posix_getgroups, posix_getlogin, posix_getpgid, posix_getpgrp, posix_getpid, posix, _getppid, posix_getpwnam, posix_getpwuid, posix_getrlimit, posix_getsid, posix_getuid, posix_isatty, posix_kill, posix_mkfifo, posix_setegid, posix_seteuid, posix_setgid, posix_setpgid, posix_setsid, posix_setuid, posix_times, posix_ttyname, posix_uname, proc_open, proc_close, proc_get_status, proc_nice, proc_terminate, phpinfo,/" /etc/php5/fpm/php.ini
RUN sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" /etc/php5/fpm/php-fpm.conf
RUN find /etc/php5/cli/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;
RUN echo "php_admin_value[sendmail_path] = /usr/bin/wp-sendmail" >> /etc/php5/fpm/pool.d/www.conf && echo "env[DB_PORT_3306_TCP_ADDR] = \$DB_PORT_3306_TCP_ADDR" >> /etc/php5/fpm/pool.d/www.conf

# User for the blog
RUN useradd -s /bin/bash -d /home/wordpress -m wordpress && usermod -aG www-data wordpress

# nginx site conf
ADD ./nginx-site.conf /etc/nginx/sites-available/default

# Supervisor Config
RUN /usr/bin/easy_install supervisor
ADD ./supervisord.conf /etc/supervisord.conf

# Install Wordpress
RUN wget http://et.wordpress.org/latest-et.tar.gz -O /wordpress.tar.gz
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

CMD env | grep _ >> /etc/environment && /bin/bash /start.sh
