FROM ruby:2.7.2-alpine3.12 AS builder
LABEL maintainer="Rapid7"

ARG BUNDLER_CONFIG_ARGS="set clean 'true' set no-cache 'true' set system 'true' set without 'development test coverage'"
ENV APP_HOME=/usr/src/metasploit-framework
ENV BUNDLE_IGNORE_MESSAGES="true"
WORKDIR $APP_HOME

COPY Gemfile* metasploit-framework.gemspec Rakefile $APP_HOME/
COPY lib/metasploit/framework/version.rb $APP_HOME/lib/metasploit/framework/version.rb
COPY lib/metasploit/framework/rails_version_constraint.rb $APP_HOME/lib/metasploit/framework/rails_version_constraint.rb
COPY lib/msf/util/helper.rb $APP_HOME/lib/msf/util/helper.rb

RUN apk add --no-cache \
      autoconf \
      bison \
      build-base \
      ruby-dev \
      openssl-dev \
      readline-dev \
      sqlite-dev \
      postgresql-dev \
      libpcap-dev \
      libxml2-dev \
      libxslt-dev \
      yaml-dev \
      zlib-dev \
      ncurses-dev \
      git \
    && echo "gem: --no-document" > /etc/gemrc \
    && gem update --system \
    && bundle config $BUNDLER_ARGS \
    && bundle install --jobs=8 \
    # temp fix for https://github.com/bundler/bundler/issues/6680
    && rm -rf /usr/local/bundle/cache \
    # needed so non root users can read content of the bundle
    && chmod -R a+r /usr/local/bundle


FROM ruby:2.7.2-alpine3.12
LABEL maintainer="tiger-framework"

ARG	LOCAL_MSF_DB_USER="msf"
ARG	LOCAL_MSF_DB_PASSWORD="msf"
ARG	LOCAL_MSF_DB="msf"
ARG REMOTE_MSF_DB="tiger_rails"
ARG REMOTE_MSF_DB_USER="tiger_rails"
ARG REMOTE_MSF_DB_PASSWORD="tiger_rails"
ARG REMOTE_MSF_DB_IPADDR=173.17.0.2
ARG DATABASE_URL=

ENV APP_HOME=/usr/src/metasploit-framework
ENV NMAP_PRIVILEGED=""
ENV METASPLOIT_GROUP=metasploit
ENV PATH="/usr/local/rvm/bin:/usr/local/rvm/rubies/ruby-${RUBY_VERSION}/bin:$PATH:$HOME/.rvm/bin"
ENV LOCAL_MSF_DB="msf"
ENV LOCAL_MSF_DB_USER="msf"
ENV LOCAL_MSF_DB_PASSWORD="msf"
ENV REMOTE_MSF_DB="tiger_rails"
ENV REMOTE_MSF_DB_USER="tiger_rails"
ENV REMOTE_MSF_DB_PASSWORD="tiger_rails"
ENV REMOTE_MSF_DB_IPADDR=173.17.0.2
ENV DATABASE_URL="postgres://${REMOTE_MSF_DB_USER}:${REMOTE_MSF_DB_PASSWORD}@${REMOTE_MSF_DB_IPADDR}:5432/${REMOTE_MSF_DB}"

RUN addgroup -S $METASPLOIT_GROUP

RUN apk add --no-cache \
  bash \
  sqlite-libs \
  nmap \
  nmap-scripts \
  nmap-nselibs \
  postgresql \
  postgresql-libs \
  python2 \
  python3 \
  ncurses \
  libcap \
  su-exec \
  alpine-sdk \
  python2-dev \
  openssl-dev \
  nasm \
  vim \
  net-tools

RUN /usr/sbin/setcap cap_net_raw,cap_net_bind_service=+eip $(which ruby)
RUN /usr/sbin/setcap cap_net_raw,cap_net_bind_service=+eip $(which nmap)

COPY --from=builder /usr/local/bundle /usr/local/bundle

RUN chown -R root:metasploit /usr/local/bundle

COPY . $APP_HOME/

RUN chown -R root:metasploit $APP_HOME/
RUN chmod 664 $APP_HOME/Gemfile.lock
RUN gem update --system
# RUN cp -f $APP_HOME/docker/database.yml $APP_HOME/config/database.yml
RUN curl -L -O https://github.com/pypa/get-pip/raw/3843bff3a0a61da5b63ea0b7d34794c5c51a2f11/get-pip.py && python get-pip.py && rm get-pip.py
RUN pip install impacket

RUN if [[ -d /var/lib/postgresql ]]; then rm -rf /var/lib/postgresql ; fi
RUN mkdir /run/postgresql
RUN chown postgres:postgres /run/postgresql/
RUN mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql
RUN su postgres -c "chmod 0700 /var/lib/postgresql/data && initdb /var/lib/postgresql/data"
RUN su postgres -c "pg_ctl start -D /var/lib/postgresql/data && sleep 10 && export PGPASSWORD=${LOCAL_MSF_DB_PASSWORD}; createuser -R -S -D ${LOCAL_MSF_DB_USER} && createdb -O ${LOCAL_MSF_DB} ${LOCAL_MSF_DB_USER}"

COPY docker/* $APP_HOME/docker/

RUN printf "local:\n    adapter: postgresql\n    database: ${LOCAL_MSF_DB}\n" > $APP_HOME/config/database.yml && \
	printf "    username: ${LOCAL_MSF_DB_USER}\n    password: ${LOCAL_MSF_DB_PASSWORD}\n" >> $APP_HOME/config/database.yml && \
	printf "    host: 127.0.0.1\n    port: 5432\n    pool: 75\n    timeout: 5\n\n" >> $APP_HOME/config/database.yml && \
  printf "production:\n    adapter: postgresql\n    database: ${REMOTE_MSF_DB}\n" >> $APP_HOME/config/database.yml && \
  printf "    username: ${REMOTE_MSF_DB_USER}\n    password: ${REMOTE_MSF_DB_PASSWORD}\n" >> $APP_HOME/config/database.yml && \
  printf "    host: ${REMOTE_MSF_DB_IPADDR}\n    port: 5432\n    pool: 200\n    timeout: 5" >> $APP_HOME/config/database.yml

# ENTRYPOINT ["docker/entrypoint.sh"]
CMD ["./msfconsole", "-r", "docker/scanport.rc"]
# CMD ['/bin/bash']
