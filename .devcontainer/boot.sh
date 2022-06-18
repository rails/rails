bundle install
yarn install

sudo chown -R vscode:vscode /usr/local/bundle

sudo service postgresql start
sudo service mariadb start
sudo service redis-server start
sudo service memcached start

# Create PostgreSQL users and databases
sudo su postgres -c "createuser --superuser vscode"
sudo su postgres -c "createdb -O vscode -E UTF8 -T template0 activerecord_unittest"
sudo su postgres -c "createdb -O vscode -E UTF8 -T template0 activerecord_unittest2"

# Create MySQL database and databases
cd activerecord
MYSQL_CODESPACES=1 bundle exec rake db:mysql:build
