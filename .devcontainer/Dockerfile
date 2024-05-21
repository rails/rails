# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.191.1/containers/ruby/.devcontainer/base.Dockerfile

# [Choice] Ruby version: 3, 3.3, 3.2, 3.1, 3.0, 2, 2.7, 2.6
ARG VARIANT="3.3.1"
FROM ghcr.io/rails/devcontainer/images/ruby:${VARIANT}

# [Optional] Uncomment this section to install additional OS packages.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
        mariadb-client libmariadb-dev \
        postgresql-client postgresql-contrib libpq-dev \
        ffmpeg mupdf mupdf-tools libvips-dev poppler-utils \
        libxml2-dev sqlite3 imagemagick

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
# Docker does not support COPY as users other than root. So we need to chown this dir so we
# can bundle as vscode user and then remove the tmp dir
RUN chown -R vscode:vscode /tmp/rails
USER vscode
RUN cd /tmp/rails \
    && /home/vscode/.rbenv/shims/bundle install \
    && rm -rf /tmp/rails
