FROM ubuntu:18.04

LABEL MAINTAINER="Michael Priest <michael.priest@adelaide.edu.au>"

LABEL io.k8s.description="Platform for serving Drupal PHP apps in Shepherd" \
      io.k8s.display-name="Shepherd Drupal" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,shepherd,drupal,php,apache" \
      io.openshift.s2i.scripts-url="image:///usr/local/s2i"

ENV DEBIAN_FRONTEND noninteractive

# Configured timezone.
ENV TZ=Australia/Adelaide
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Ensure UTF-8.
ENV LANG       en_AU.UTF-8
ENV LANGUAGE   en_AU:en
ENV LC_ALL     en_AU.UTF-8

# Upgrade all currently installed packages and install web server packages.
RUN apt-get update \
&& apt-get -y install locales \
&& sed -i -e 's/# en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen \
&& locale-gen en_AU.UTF-8 \
&& apt-get -y dist-upgrade \
&& apt-get -y install \
  apache2 \
  git \
  libapache2-mod-php \
  libedit-dev \
  mysql-client \
  openssh-client \
  php-common \
  php-apcu \
  php-bcmath \
  php-curl \
  php-gd \
  php-ldap \
  php-mbstring \
  php-mysql \
  php-opcache \
  php-redis \
  php-soap \
  php-xml \
  php-zip \
  ssmtp \
  unzip \
  wget \
&& apt-get -y autoremove && apt-get -y autoclean && apt-get clean && rm -rf /var/lib/apt/lists /tmp/* /var/tmp/*

# Install Composer.
RUN wget -q https://getcomposer.org/installer -O - | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer global require --no-interaction hirak/prestissimo

# Make bash the default shell.
RUN ln -sf /bin/bash /bin/sh

# Apache config.
COPY ./files/apache2.conf /etc/apache2/apache2.conf

# PHP config.
COPY ./files/php_custom.ini /etc/php/7.2/mods-available/php_custom.ini

# Configure apache modules, php modules, logging.
RUN a2enmod rewrite \
&& a2dismod vhost_alias \
&& a2disconf other-vhosts-access-log \
&& a2dissite 000-default \
&& phpenmod -v ALL -s ALL php_custom

# Add /code /shared directories and ensure ownership by User 33 (www-data) and Group 0 (root).
RUN mkdir -p /code /shared

# Add s2i scripts.
COPY ./s2i/bin /usr/local/s2i
RUN chmod +x /usr/local/s2i/*
ENV PATH "$PATH:/usr/local/s2i:/code/bin"

# Web port.
EXPOSE 8080

# Set working directory.
WORKDIR /code

# Change all ownership to User 33 (www-data) and Group 0 (root).
RUN chown -R 33:0   /var/www \
&&  chown -R 33:0   /run/lock \
&&  chown -R 33:0   /var/run/apache2 \
&&  chown -R 33:0   /var/log/apache2 \
&&  chown -R 33:0   /code \
&&  chown -R 33:0   /shared

RUN chmod -R g+rwX  /var/www \
&&  chmod -R g+rwX  /run/lock \
&&  chmod -R g+rwX  /var/run/apache2 \
&&  chmod -R g+rwX  /var/log/apache2 \
&&  chmod -R g+rwX  /code \
&&  chmod -R g+rwX  /shared

# Change the homedir of www-data to be /code.
RUN usermod -d /code www-data

USER 33:0

# Start the web server.
CMD ["/usr/local/s2i/run"]
