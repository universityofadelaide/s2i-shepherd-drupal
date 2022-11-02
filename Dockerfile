FROM ubuntu:22.04

LABEL MAINTAINER="Michael Priest <michael.priest@adelaide.edu.au>"

LABEL io.k8s.description="Platform for serving Drupal PHP apps in Shepherd" \
      io.k8s.display-name="Shepherd Drupal" \
      io.openshift.expose-services="8080:http" \
      io.openshift.tags="builder,shepherd,drupal,php,apache" \
      io.openshift.s2i.scripts-url="image:///usr/local/s2i"

ARG PHP="7.4"

# Ensure shell is what we want.
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND noninteractive

# Configured timezone.
ENV TZ=Australia/Adelaide
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Upgrade all currently installed packages and install web server packages.
RUN apt-get update \
&& apt-get -y --no-install-recommends install ca-certificates apt apt-utils \
&& apt-get -y upgrade \
&& apt-get -y --no-install-recommends install openssh-client patch software-properties-common locales gnupg2 gpg-agent wget \
&& sed -i -e 's/# en_AU.UTF-8 UTF-8/en_AU.UTF-8 UTF-8/' /etc/locale.gen \
&& locale-gen en_AU.UTF-8 \
&& wget -q -O- https://download.newrelic.com/548C16BF.gpg | apt-key add - \
&& echo 'deb http://apt.newrelic.com/debian/ newrelic non-free' | tee /etc/apt/sources.list.d/newrelic.list \
&& add-apt-repository -y ppa:ondrej/php \
&& apt-get -y update \
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
  libapache2-mod-php${PHP} \
  libedit-dev \
  mariadb-client \
  newrelic-php5 \
  patch \
  php${PHP}-apcu \
  php${PHP}-bcmath \
  php${PHP}-common \
  php${PHP}-curl \
  php${PHP}-gd \
  php${PHP}-ldap \
  php${PHP}-mbstring \
  php${PHP}-memcached \
  php${PHP}-mysql \
  php${PHP}-opcache \
  php${PHP}-redis \
  php${PHP}-soap \
  php${PHP}-xml \
  php${PHP}-zip \
  rsync \
  ssh-client \
  ssmtp \
  telnet \
  unzip \
  wget \
&& apt-get -y autoremove && apt-get -y autoclean && apt-get clean && rm -rf /var/lib/apt/lists /tmp/* /var/tmp/*

# NewRelic is disabled by default.
ENV NEW_RELIC_ENABLED=false

# Remove the default newrelic config.
RUN rm -f /etc/php/${PHP}/mods-available/newrelic.ini /etc/php/${PHP}/apache2/conf.d/20-newrelic.ini /etc/php/${PHP}/cli/conf.d/20-newrelic.ini

# Set the PHP interpreter to the correct one.
RUN update-alternatives --set php /usr/bin/php${PHP}

# Install Composer.
RUN wget -q -O - https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Install PHP Local Security Checker
RUN wget -q -O /usr/local/bin/local-php-security-checker https://github.com/fabpot/local-php-security-checker/releases/download/v2.0.3/local-php-security-checker_2.0.3_linux_amd64 \
&& chmod +rx /usr/local/bin/local-php-security-checker

# Apache config.
COPY ./files/apache2.conf /etc/apache2/apache2.conf
COPY ./files/mpm_prefork.conf /etc/apache2/mods-available/mpm_prefork.conf

# PHP config.
COPY ./files/php_custom.ini /etc/php/${PHP}/mods-available/php_custom.ini
COPY ./files/newrelic.ini /etc/php/${PHP}/apache2/conf.d/newrelic.ini

# Configure apache modules, php modules, logging.
RUN a2enmod rewrite \
&& a2enmod mpm_prefork \
&& a2dismod vhost_alias \
&& a2disconf other-vhosts-access-log \
&& a2dissite 000-default \
&& phpenmod -v ALL -s ALL php_custom

# Add /code /shared directories and ensure ownership by User 33 (www-data) and Group 0 (root).
RUN mkdir -p /code/web /shared

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
&&  chmod -R g+rwX  /shared \
&&  chmod g+s /code \
&&  chmod g+s /code/web

# Change the homedir of www-data to be /code.
RUN usermod -d /code www-data

USER 33:0

# Start the web server.
CMD ["/usr/local/s2i/run"]
