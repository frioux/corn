FROM phusion/baseimage:0.9.16
MAINTAINER Arthur Axel fREW Schmdit <frioux@gmail.com>

CMD ["/sbin/my_init"]
VOLUME ["/opt/var/", "/opt/log"]
EXPOSE 5000

ADD . /opt/app
ADD corn.sh /etc/service/corn/run
ADD log.sh /etc/service/corn/log/run

ENV PERL5LIB lib:local/lib/perl5
ENV CORN_SILO /opt/var/
ENV CORN_LOG /opt/log/

WORKDIR /opt/app
RUN env DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y carton daemontools build-essential libxml2-dev \
 && carton install -v --deployment \
 && rm -rf ~/.cpanm local/cache local/man \
 && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
