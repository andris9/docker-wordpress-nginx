# docker-wordpress-nginx

This is a fork of [eugeneware/docker-wordpress-nginx](https://github.com/eugeneware/docker-wordpress-nginx). I wanted to move some real world blogs to Docker and this project seemed like a nice basis for it. I changed a few things like allowing larger file uploads, made WordPress auto upgrade work through SSH, changed file permissions so that web user is only allowed to modify uploads directory (PHP files from this directory are not executed) etc. Wordpress user password for auto upgrade can be found from the logs as "user password".

For security reasons I created a sendmail replacement daemon that only sends messages to valid users found from the MySQL WordPress users table and not to arbitrary e-mail addresses. Downside is that you need to provide valid SMTP information for the container.

One reason why you might not want to use this Dockerfile without modification is that the WordPress version installed is in Estonian language. You can change this this [here](Dockerfile#L61).

For upgrading WordPress version or adding themes/plugins through WordPress admin interface, use SSH user password found from the logs

----

A Dockerfile that installs the latest wordpress, nginx, php-apc and php-fpm.

NB: A big thanks to [jbfink](https://github.com/jbfink/docker-wordpress) who did most of the hard work on the wordpress parts!

You can check out his [Apache version here](https://github.com/jbfink/docker-wordpress).

## Installation

```
$ git clone https://github.com/eugeneware/docker-wordpress-nginx.git
$ cd docker-wordpress-nginx
$ sudo docker build -t="docker-wordpress-nginx" .
```

## Usage

To spawn a new instance of wordpress:

```bash
$ sudo docker run -p 80 -d docker-wordpress-nginx
```

You'll see an ID output like:
```
d404cc2fa27b
```

Use this ID to check the port it's on:
```bash
$ sudo docker port d404cc2fa27b 80 # Make sure to change the ID to yours!
```

This command returns the container ID, which you can use to find the external port you can use to access Wordpress from your host machine:

```
$ docker port <container-id> 80
```

You can the visit the following URL in a browser on your host machine to get started:

```
http://127.0.0.1:<port>
```

### E-mail

If you want to send mail you need to provide SMTP connection data by adding `-e SMTP=smtpdata` option to `docker run`. This information is not exposed to the php user. 

For example if you want to use Gmail as your SMTP provider, use the following command (replace the user and password with your own).

```bash
docker run -p 80 -d -e SMTP="smpt://user.name@gmail.com:password@smtp.gmail.com:587" docker-wordpress-nginx
```

To add additional security, block outgoing port 25 for your docker containers by running in the docker host:

```bash
iptables -I FORWARD -p tcp --dport 25 -j DROP
```

> **NB!** this blocks port 25 for all docker containers in this host, consult iptables documentation if you want to block only specific containers

### Features

  * File uploads are limited to 10MB
  * You can use a SMTP provider for outgoing e-mail (SendGrid, Gmail, Mailgun etc.)
  * WordPress auto upgrade works through SSH and is preconfigured, only user password needs to be provided
  * Static files are aggressively cached

### Security features

  * A lot of functions (including all shell functions and phpinfo) are disabled.
  * All outgoing e-mails are checked - if recipients can't be found from the users table or admin email option, the mail is discarded. Helps against trojans that are using PHP `mail()` command.
  * All WordPress files belong to user `wordpress`, php is executed as `www-data`
  * Only writable folder for user `www-data` is */uploads* - executing php scripts is forbidden from this directory. Helps against attackers that upload php files to server
  * Server and PHP versions are not advertised with headers
  * WordPress MySQL user has only required privileges
  * No errors are shown to the user
  * 403 errors are displayed as 404
  * WordPress theme and plugin editor is disabled (and would not work anyway as theme and plugin directories are not writable for the php user)

### Security issues

  *  You should block outgoing port 25 in the host machine (you can configure wp-sendmail to use another port). Helps against trojans that are using port 25 for SMTP
  * `open_basedir` could be useful but currently is not set as it broke WordPress auto upgrading
  * `allow_url_fopen` is on - setting it off broke WordPress auto upgrade
  * `wp-config.php` should be only owner readable but `www-data` needs to access it too, so file permissions are not changed

