# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.191.1/containers/ruby/.devcontainer/base.Dockerfile

# [Choice] Ruby version: 3, 3.0, 2, 2.7, 2.6
ARG VARIANT="3.0"
FROM mcr.microsoft.com/devcontainers/ruby:0-${VARIANT}

# [Choice] Node.js version: none, lts/*, 16, 14, 12, 10
ARG NODE_VERSION="none"
RUN if [ "${NODE_VERSION}" != "none" ]; then su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1"; fi

# [Optional] Uncomment this section to install additional OS packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        mariadb-server libmariadb-dev \
        postgresql postgresql-client postgresql-contrib libpq-dev \
        redis-server memcached \
        ffmpeg mupdf mupdf-tools libvips poppler-utils


ARG IMAGEMAGICK_VERSION="7.1.0-5"
RUN wget -qO /tmp/im.tar.xz https://imagemagick.org/archive/releases/ImageMagick-$IMAGEMAGICK_VERSION.tar.xz \
    && wget -qO /tmp/im.sig https://imagemagick.org/archive/releases/ImageMagick-$IMAGEMAGICK_VERSION.tar.xz.asc \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv 89AB63D48277377A \
    && gpg --batch --verify /tmp/im.sig /tmp/im.tar.xz \
    && tar xJf /tmp/im.tar.xz -C /tmp \
    && cd /tmp/ImageMagick-$IMAGEMAGICK_VERSION \
    && ./configure --with-rsvg && make -j 9 && make install \
    && ldconfig /usr/local/lib \
    && rm -rf /tmp/*

# Add the Rails main Gemfile and install the gems. This means the gem install can be done
# during build instead of on start. When a fork or branch has different gems, we still have an
# advantage due to caching of the other gems.
RUN mkdir -p /tmp/rails
COPY Gemfile Gemfile.lock RAILS_VERSION rails.gemspec package.json yarn.lock /tmp/rails/
COPY actioncable/actioncable.gemspec /tmp/rails/actioncable/
COPY actionmailbox/actionmailbox.gemspec /tmp/rails/actionmailbox/
COPY actionmailer/actionmailer.gemspec /tmp/rails/actionmailer/
COPY actionpack/actionpack.gemspec /tmp/rails/actionpack/
COPY actiontext/actiontext.gemspec /tmp/rails/actiontext/
COPY actionview/actionview.gemspec /tmp/rails/actionview/
COPY activejob/activejob.gemspec /tmp/rails/activejob/
COPY activemodel/activemodel.gemspec /tmp/rails/activemodel/
COPY activerecord/activerecord.gemspec /tmp/rails/activerecord/
COPY activestorage/activestorage.gemspec /tmp/rails/activestorage/
COPY activesupport/activesupport.gemspec /tmp/rails/activesupport/
COPY railties/railties.gemspec /tmp/rails/railties/
RUN cd /tmp/rails \
    && bundle install \
    && yarn install \
    && rm -rf /tmp/rails
