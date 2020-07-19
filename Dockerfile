FROM ruby:2.6.5

RUN apt-get update
RUN apt-get --yes --force-yes install build-essential patch ruby-dev zlib1g-dev liblzma-dev
RUN gem install bundler
WORKDIR /rails
COPY . ./
RUN bundle config build.nokogiri --use-system-libraries
RUN bundle check || bundle install
