#!/bin/sh

bundle update --bundler
bundle install

if [ -n "${NVM_DIR}" ]; then
  # shellcheck disable=SC1091
  . "${NVM_DIR}/nvm.sh" && nvm install --lts
  yarn install
fi

cd activerecord || { echo "activerecord directory doesn't exist"; exit; }

# Create PostgreSQL databases
bundle exec rake db:postgresql:rebuild

# Create MySQL databases
bundle exec rake db:mysql:rebuild
