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
$ sudo docker run -p 80 -d -e SMTP="smtp://user:pass@localhost:port" docker-wordpress-nginx
```

If you want to send mail you need to provide SMTP connection data. This information is not exposed to the php user. 

For example if you want to use Gmail as your SMTP provider, use the following command (replace the user and password with your own).

docker run -p 80 -d -e SMTP="smpt://user.name@gmail.com:password@smtp.gmail.com:587" docker-wordpress-nginx

To add additional security, block outgoing port 25 for your docker containers by running in the docker host:

```bash
iptables -I FORWARD -p tcp --dport 25 -j DROP
```

> **NB!** this blocks port 25 for all docker containers in this host, consult iptables documentation if you want to block only specific containers

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
