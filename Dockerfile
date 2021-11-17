FROM ubuntu:20.04

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

# Ensure shell is what we want.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Upgrade all currently installed packages and install web server packages.
RUN apt-get update \
&& apt-get -y --no-install-recommends install ca-certificates locales \
&& sed -i -e 's/# en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen \
&& locale-gen en_AU.UTF-8 \
&& apt-get -y upgrade \
&& apt-get -y --no-install-recommends install \
  apache2 \
  bind9-host \
  ca-certificates \
  git \
  gnupg2 \
  iproute2 \
  iputils-ping \
  less \
  libapache2-mod-php \
  libedit-dev \
  mariadb-client \
  patch \
  php-apcu \
  php-bcmath \
  php-common \
  php-curl \
  php-gd \
  php-ldap \
  php-mbstring \
  php-memcached \
  php-mysql \
  php-opcache \
  php-redis \
  php-soap \
  php-xml \
  php-zip \
  rsync \
  ssh-client \
  ssmtp \
  telnet \
  unzip \
  wget \
&& apt-get -y autoremove && apt-get -y autoclean && apt-get clean && rm -rf /var/lib/apt/lists /tmp/* /var/tmp/*

# NewRelic is disabled by default.
ENV NEW_RELIC_ENABLED=false

# Install NewRelic agent https://docs.newrelic.com/docs/agents/php-agent/installation/php-agent-installation-ubuntu-debian
RUN echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' | tee /etc/apt/sources.list.d/newrelic.list \
&& wget -q -O - https://download.newrelic.com/548C16BF.gpg | apt-key add - \
&& apt-get update \
&& apt-get install -y --no-install-recommends newrelic-php5 \
&& rm -f /etc/php/7.4/mods-available/newrelic.ini /etc/php/7.4/apache2/conf.d/20-newrelic.ini /etc/php/7.4/cli/conf.d/20-newrelic.ini \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Install Composer.
RUN wget -q -O - https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install PHP Local Security Checker
RUN wget -q -O /usr/local/bin/local-php-security-checker https://github.com/fabpot/local-php-security-checker/releases/download/v1.0.0/local-php-security-checker_1.0.0_linux_amd64 \
&& chmod +rx /usr/local/bin/local-php-security-checker

# Apache config.
COPY ./files/apache2.conf /etc/apache2/apache2.conf

# PHP config.
COPY ./files/php_custom.ini /etc/php/7.4/mods-available/php_custom.ini
COPY ./files/newrelic.ini /etc/php/7.4/apache2/conf.d/newrelic.ini

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
