FROM perl:5.20.1
MAINTAINER Arthur Axel fREW Schmdit <frioux@gmail.com>

ADD . /opt/app
WORKDIR /opt/app
EXPOSE 5000
ENV PERL5LIB lib:local/lib/perl5
ENV CORN_SILO /opt/var/
VOLUME ["/opt/var/"]

RUN cpanm -n Carton \
 && carton install --deployment \
 && rm -rf ~/.cpanm local/cache local/man

CMD ["perl", "-Ilocal/lib/perl5", "local/bin/plackup", "-s", "Gazelle", "-E", "production"]
