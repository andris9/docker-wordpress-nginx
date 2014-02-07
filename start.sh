#!/bin/bash

# DB_PASSWORD=$(awk -F "'" '/DB_PASSWORD/ {print $4}' /var/data/sources/wp-config.php)
# DB_USER=$(awk -F "'" '/DB_USER/ {print $4}' /var/data/sources/wp-config.php)
# DB_NAME=$(awk -F "'" '/DB_NAME/ {print $4}' /var/data/sources/wp-config.php)

if [ ! -f /usr/share/nginx/www/wp-config.php ]; then
  
  # Set these with -e option
  # WORDPRESS_DB="wordpress"
  # MYSQLPASS="12345"
  
  MYSQL_USER_PASSWORD=`pwgen -c -n -1 12`
  SSH_ROOT_PASSWORD=`pwgen -c -n -1 12`
  SSH_USER_PASSWORD=`pwgen -c -n -1 12`

  # Expose passwords in logs
  echo MySQL user password: $MYSQL_USER_PASSWORD
  echo SSH root password: $SSH_ROOT_PASSWORD
  echo SSH user password: $SSH_USER_PASSWORD

  # Change SSH passwords
  echo "root:$SSH_ROOT_PASSWORD" | chpasswd
  echo "wordpress:$SSH_USER_PASSWORD" | chpasswd

  #mysql has to be started this way as it doesn't work to call from /etc/init.d
  # /usr/bin/mysqld_safe &
  # sleep 10s

  # setup directories
  WORDPRESS_ROOT="/usr/share/nginx/www"
  WORDPRESS_UPLOADS="uploads"
  mkdir -p "$WORDPRESS_ROOT/$WORDPRESS_UPLOADS"

  # create a link of wordpress directory to ssh user home
  ln -s $WORDPRESS_ROOT /home/wordpress/wordpress

  # Escape any unsopperted chars, eg "/"
  SAFE_WORDPRESS_UPLOADS=$(printf '%s\n' "$WORDPRESS_UPLOADS" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
  SAFE_WORDPRESS_ROOT=$(printf '%s\n' "$WORDPRESS_ROOT/" | sed 's/[[\.*^$(){}?+|/]/\\&/g')

  # Create wp-config.php with selected values
  sed -e "s/database_name_here/$WORDPRESS_DB/
s/username_here/$WORDPRESS_DB/
s/password_here/$MYSQL_USER_PASSWORD/
/'DB_HOST'/s/'localhost'/getenv(\"DB_PORT_3306_TCP_ADDR\")/
/'AUTH_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
/'SECURE_AUTH_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
/'LOGGED_IN_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
/'NONCE_KEY'/s/put your unique phrase here/`pwgen -c -n -1 65`/
/'AUTH_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
/'SECURE_AUTH_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
/'LOGGED_IN_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
/'NONCE_SALT'/s/put your unique phrase here/`pwgen -c -n -1 65`/
/'WP_DEBUG'/{G;s/$/define( 'UPLOADS', '$SAFE_WORDPRESS_UPLOADS' );/;}
/'WP_DEBUG'/{G;s/$/define( 'FS_METHOD', 'ssh2' );/;}
/'WP_DEBUG'/{G;s/$/define( 'FTP_BASE', '$SAFE_WORDPRESS_ROOT' );/;}
/'WP_DEBUG'/{G;s/$/define( 'FTP_USER', 'wordpress' );/;}
/'WP_DEBUG'/{G;s/$/define( 'FTP_HOST', 'localhost' );/;}
/'WP_DEBUG'/{G;s/$/define( 'FTP_SSL', true );/;}
/'WP_DEBUG'/{G;s/$/define( 'FTP_PUBKEY', false );/;}
/'WP_DEBUG'/{G;s/$/define( 'FTP_PRIKEY', false );/;}
/'WP_DEBUG'/{G;s/$/define( 'DISALLOW_FILE_EDIT', true );/;}" /usr/share/nginx/www/wp-config-sample.php > /usr/share/nginx/www/wp-config.php

  # Download nginx helper plugin
  curl -O `curl -i -s http://wordpress.org/plugins/nginx-helper/ | egrep -o "http://downloads.wordpress.org/plugin/[^']+"`
  unzip nginx-helper.*.zip -d /usr/share/nginx/www/wp-content/plugins
  chown -R wordpress:wordpress /usr/share/nginx/www/wp-content/plugins/nginx-helper

  # Activate nginx plugin and set up pretty permalink structure once logged in
  cat << ENDL >> /usr/share/nginx/www/wp-config.php
\$plugins = get_option( 'active_plugins' );
if ( count( \$plugins ) === 0 ) {
    require_once(ABSPATH .'/wp-admin/includes/plugin.php');
    \$wp_rewrite->set_permalink_structure( '/%postname%/' );
    \$pluginsToActivate = array( 'nginx-helper/nginx-helper.php' );
    foreach ( \$pluginsToActivate as \$plugin ) {
        if ( !in_array( \$plugin, \$plugins ) ) {
            activate_plugin( '/usr/share/nginx/www/wp-content/plugins/' . \$plugin );
        }
    }
}
ENDL

  # Ensure proper file permissions and ownership
  chown wordpress:wordpress -R /usr/share/nginx/www
  chown www-data:www-data -R "$WORDPRESS_ROOT/$WORDPRESS_UPLOADS"
  find "$WORDPRESS_ROOT" -type d -exec chmod 755 {} \;
  find "$WORDPRESS_ROOT" -type f -exec chmod 644 {} \;

  # email settings
  sed -i -e "s/MYSQL_PASSWORD/$MYSQL_USER_PASSWORD/;s/MYSQL_PREFIX/wp_/" /etc/wp-sendmail.js
  chown root:root /etc/wp-sendmail.js
  chmod 0400 /etc/wp-sendmail.js
  rm -rf /etc/wp-sendmail.js-e

  # Create database user for WordPress database
  # echo mysqladmin -u root password $MYSQLPASS
  mysql -h $DB_PORT_3306_TCP_ADDR -uroot -p$MYSQLPASS -e "DROP DATABASE IF EXISTS $WORDPRESS_DB; CREATE DATABASE $WORDPRESS_DB; GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, DROP, INDEX ON $WORDPRESS_DB.* TO '$WORDPRESS_DB'@'%' IDENTIFIED BY '$MYSQL_USER_PASSWORD'; FLUSH PRIVILEGES;"
  # killall mysqld
fi

# start all the services
/usr/local/bin/supervisord -n
