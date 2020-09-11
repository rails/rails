FROM ruby:2.6.6

RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - && \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    default-libmysqlclient-dev \
    default-mysql-client \
    ffmpeg \
    imagemagick \
    locales \
    mupdf \
    mupdf-tools \
    poppler-utils \
    postgresql-client \
    sqlite3 \
    yarn \
 && rm -rf /var/lib/apt/lists/* \
 && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
 && dpkg-reconfigure --frontend=noninteractive locales \
 && update-locale LANG=en_US.UTF-8

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
ENV LC_ALL en_US.UTF-8

WORKDIR /usr/src/rails

RUN gem install bundler

COPY Gemfile* rails.gemspec RAILS_VERSION package.json yarn.lock ./
COPY actioncable/actioncable.gemspec actioncable/package.json ./actioncable/
COPY actionmailbox/actionmailbox.gemspec ./actionmailbox/
COPY actionmailer/actionmailer.gemspec ./actionmailer/
COPY actionpack/actionpack.gemspec ./actionpack/
COPY actiontext/actiontext.gemspec actiontext/package.json ./actiontext/
COPY actionview/actionview.gemspec actionview/package.json ./actionview/
COPY activejob/activejob.gemspec ./activejob/
COPY activemodel/activemodel.gemspec ./activemodel/
COPY activerecord/activerecord.gemspec ./activerecord/
COPY activestorage/activestorage.gemspec activestorage/package.json ./activestorage/
COPY activesupport/activesupport.gemspec ./activesupport/
COPY railties/railties.gemspec ./railties/

RUN bundle install \
 && yarn install

COPY . ./

CMD ["bash"]
