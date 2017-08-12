FROM ruby:<%= RUBY_VERSION %>
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs
RUN mkdir /<%= app_name %>
WORKDIR /<%= app_name %>
ADD Gemfile /<%= app_name %>/Gemfile
ADD Gemfile.lock /<%= app_name %>/Gemfile.lock
RUN bundle install
ADD . /<%= app_name %>
