bundle install
yarn install

sudo chown -R vscode:vscode /usr/local/bundle

sudo service mariadb start
sudo service redis-server start
sudo service memcached start

cd activerecord

# Create PostgreSQL databases
bundle exec rake db:postgresql:rebuild

# Create MySQL databases
MYSQL_CODESPACES=1 bundle exec rake db:mysql:rebuild
