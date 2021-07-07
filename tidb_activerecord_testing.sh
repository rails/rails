#!/bin/bash

set -eo pipefail

bundle config set --local path '.bundle' 

echo "Setup gem mirror"
bundle config mirror.https://rubygems.org https://gems.ruby-china.com 

echo "Bundle install"
bundle install

echo "Setup database for testing"
cd activerecord && bundle exec rake db:mysql:rebuild && bundle exec rake test:mysql2
