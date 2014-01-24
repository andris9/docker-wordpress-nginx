#!/bin/bash

# DB_PASSWORD=$(awk -F "'" '/DB_PASSWORD/ {print $4}' /var/data/sources/wp-config.php)
# DB_USER=$(awk -F "'" '/DB_USER/ {print $4}' /var/data/sources/wp-config.php)
# DB_NAME=$(awk -F "'" '/DB_NAME/ {print $4}' /var/data/sources/wp-config.php)

if [ ! -f /usr/share/nginx/www/wp-config.php ]; then
  #mysql has to be started this way as it doesn't work to call from /etc/init.d
  /usr/bin/mysqld_safe &
  sleep 10s
  # Here we generate random passwords (thank you pwgen!). The first two are for mysql users, the last batch for random keys in wp-config.php
  WORDPRESS_DB="wordpress"
  ROOT_PASSWORD=`pwgen -c -n -1 12`
  USER_PASSWORD=`pwgen -c -n -1 12`

  WORDPRESS_ROOT="/usr/share/nginx/www"
  WORDPRESS_UPLOADS="uploads"

  mkdir -p "$WORDPRESS_ROOT/$WORDPRESS_UPLOADS"

  ln -s $WORDPRESS_ROOT /home/wordpress/wordpress

  echo "root:$ROOT_PASSWORD" | chpasswd
  echo "wordpress:$USER_PASSWORD" | chpasswd

  # Expose passwords in logs
  echo root password: $ROOT_PASSWORD
  echo user password: $USER_PASSWORD

  # Escape any unsopperted chars, eg "/"
  SAFE_WORDPRESS_UPLOADS=$(printf '%s\n' "$WORDPRESS_UPLOADS" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
  SAFE_WORDPRESS_ROOT=$(printf '%s\n' "$WORDPRESS_ROOT/" | sed 's/[[\.*^$(){}?+|/]/\\&/g')

  sed -e "s/database_name_here/$WORDPRESS_DB/
s/username_here/$WORDPRESS_DB/
s/password_here/$USER_PASSWORD/
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

  chown wordpress:wordpress -R /usr/share/nginx/www
  chown www-data:www-data -R "$WORDPRESS_ROOT/$WORDPRESS_UPLOADS"

  find "$WORDPRESS_ROOT" -type d -exec chmod 755 {} \;
  find "$WORDPRESS_ROOT" -type f -exec chmod 644 {} \;

  # create dummy sendmail client
  SENDMAIL_LOG="/var/log/sendmail.log"
  echo "#!/bin/bash

SENDMAIL_LOG=\"$SENDMAIL_LOG\"

echo \"[`date`]\" >> \$SENDMAIL_LOG
echo \"\$0 \$*\" >> \$SENDMAIL_LOG

while read line
do
  echo \"\$line\" >> \$SENDMAIL_LOG
done < /proc/\${\$}/fd/0

echo \"\" >> \$SENDMAIL_LOG" > /usr/bin/sendmail
  chmod +x /usr/bin/sendmail
  touch $SENDMAIL_LOG
  chown www-data:www-data $SENDMAIL_LOG

  mysqladmin -u root password $ROOT_PASSWORD
  mysql -uroot -p$ROOT_PASSWORD -e "CREATE DATABASE wordpress; GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost' IDENTIFIED BY '$USER_PASSWORD'; FLUSH PRIVILEGES;"
  killall mysqld
fi

# start all the services
/usr/local/bin/supervisord -n
