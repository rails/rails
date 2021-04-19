ARG RUBY_IMAGE
FROM ${RUBY_IMAGE:-ruby:latest}

ARG BUNDLER
ARG RUBYGEMS
RUN echo "--- :ruby: Updating RubyGems and Bundler" \
    && (gem update --system ${RUBYGEMS:-} || gem update --system 2.7.8) \
    && (gem install bundler -v "${BUNDLER:->= 0}" || gem install bundler -v "< 2") \
    && ruby --version && gem --version && bundle --version \
    && echo "--- :package: Installing system deps" \
    && codename="$(. /etc/os-release; x="${VERSION_CODENAME-${VERSION#*(}}"; echo "${x%%[ )]*}")" \
    && if [ "$codename" = jessie ]; then \
        # jessie-updates is gone
        sed -i -e '/jessie-updates/d' /etc/apt/sources.list \
        && echo 'deb http://archive.debian.org/debian jessie-backports main' > /etc/apt/sources.list.d/backports.list \
        && echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/backports-is-unsupported; \
    fi \
    # Pre-requirements
    && if ! which gpg || ! which curl; then \
        apt-get update \
        && apt-get install -y --no-install-recommends \
            gnupg curl; \
    fi \
    # Postgres apt sources
    && curl -sS https://www.postgresql.org/media/keys/ACCC4CF8.asc | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - \
    && echo "deb http://apt.postgresql.org/pub/repos/apt/ ${codename}-pgdg main" > /etc/apt/sources.list.d/pgdg.list \
    # Node apt sources
    && curl -sS https://deb.nodesource.com/gpgkey/nodesource.gpg.key | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - \
    && echo "deb http://deb.nodesource.com/node_10.x ${codename} main" > /etc/apt/sources.list.d/nodesource.list \
    # Yarn apt sources
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - \
    && echo "deb http://dl.yarnpkg.com/debian/ stable main" > /etc/apt/sources.list.d/yarn.list \
    # Install all the things
    && apt-get update \
    #  buildpack-deps
    && apt-get install -y --no-install-recommends \
        autoconf \
        automake \
        bzip2 \
        dpkg-dev \
        file \
        g++ \
        gcc \
        imagemagick \
        libbz2-dev \
        libc6-dev \
        libcurl4-openssl-dev \
        libdb-dev \
        libevent-dev \
        libffi-dev \
        libgdbm-dev \
        libgeoip-dev \
        libglib2.0-dev \
        libjpeg-dev \
        libkrb5-dev \
        liblzma-dev \
        libmagickcore-dev \
        libmagickwand-dev \
        libncurses5-dev \
        libncursesw5-dev \
        libpng-dev \
        libpq-dev \
        libreadline-dev \
        libsqlite3-dev \
        libssl-dev \
        libtool \
        libvips-dev \
        libwebp-dev \
        libxml2-dev \
        libxslt-dev \
        libyaml-dev \
        make \
        patch \
        unzip \
        xz-utils \
        zlib1g-dev \
        \
# https://lists.debian.org/debian-devel-announce/2016/09/msg00000.html
        $( \
# if we use just "apt-cache show" here, it returns zero because "Can't select versions from package 'libmysqlclient-dev' as it is purely virtual", hence the pipe to grep
            if apt-cache show 'default-libmysqlclient-dev' 2>/dev/null | grep -q '^Version:'; then \
                echo 'default-libmysqlclient-dev'; \
            else \
                echo 'libmysqlclient-dev'; \
            fi \
        ) \
    #  specific dependencies for the rails build
    && apt-get install -y --no-install-recommends \
        postgresql-client default-mysql-client sqlite3 \
        git nodejs yarn lsof \
        ffmpeg mupdf mupdf-tools poppler-utils \
    # await (for waiting on dependent services)
    && curl -fLsS -o /tmp/await-linux-amd64 https://github.com/betalo-sweden/await/releases/download/v0.4.0/await-linux-amd64 \
    && install /tmp/await-linux-amd64 /usr/local/bin/await \
    # clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* \
    && mkdir /rails

WORKDIR /rails
ENV RAILS_ENV=test RACK_ENV=test
ENV JRUBY_OPTS="--dev -J-Xmx1024M"

ADD .buildkite/await-all .buildkite/runner /usr/local/bin/
RUN chmod +x /usr/local/bin/await-all /usr/local/bin/runner

# Wildcard ignores missing files; .empty ensures ADD always has at least
# one valid source: https://stackoverflow.com/a/46801962
ADD .buildkite/.empty actioncable/package.jso[n] actioncable/
ADD .buildkite/.empty actiontext/package.jso[n] actiontext/
ADD .buildkite/.empty actionview/package.jso[n] actionview/
ADD .buildkite/.empty activestorage/package.jso[n] activestorage/
ADD .buildkite/.empty package.jso[n] yarn.loc[k] .yarnr[c] ./

RUN rm -f .empty */.empty \
    && find . -maxdepth 1 -type d -empty -exec rmdir '{}' '+' \
    && if [ -f package.json ]; then \
        echo "--- :javascript: Installing JavaScript deps" \
        && yarn install \
        && yarn cache clean; \
    elif [ -f actionview/package.json ]; then \
        echo "--- :javascript: Installing JavaScript deps" \
        && (cd actionview && npm install); \
    fi

ADD */*.gemspec tmp/
ADD .buildkite/.empty railties/exe/* railties/exe/
ADD Gemfile Gemfile.lock RAILS_VERSION rails.gemspec ./

RUN rm -f railties/exe/.empty \
    && find railties/exe -maxdepth 0 -type d -empty -exec rmdir '{}' '+' \
    && echo "--- :bundler: Installing Ruby deps" \
    && (cd tmp && for f in *.gemspec; do d="$(basename -s.gemspec "$f")"; mkdir -p "../$d" && mv "$f" "../$d/"; done) \
    && rm Gemfile.lock && bundle install -j 8 && cp Gemfile.lock tmp/Gemfile.lock.updated \
    && rm -rf /usr/local/bundle/cache \
    && echo "--- :floppy_disk: Copying repository contents"

ADD . ./

RUN mv -f tmp/Gemfile.lock.updated Gemfile.lock \
    && if [ -f package.json ]; then \
        echo "--- :javascript: Building JavaScript package" \
        && (cd actionview && yarn build) \
        && if [ -f railties/test/isolation/assets/package.json ]; then \
            (cd railties/test/isolation/assets && yarn install); \
        fi \
        && yarn cache clean; \
    fi
