bundle install

. ${NVM_DIR}/nvm.sh && nvm install --lts
yarn install

cd activerecord

# Create PostgreSQL databases
bundle exec rake db:postgresql:rebuild

# Create MySQL databases
MYSQL_CODESPACES=1 bundle exec rake db:mysql:rebuild
