bundle install
yarn install

sudo chown -R vscode:vscode /usr/local/bundle/bundler

sudo service postgresql start
sudo service mariadb start
sudo service redis-server start
sudo service memcached start

# Create PostgreSQL users and databases
sudo su postgres -c "createuser --superuser vscode"
sudo su postgres -c "createdb -O vscode -E UTF8 -T template0 activerecord_unittest"
sudo su postgres -c "createdb -O vscode -E UTF8 -T template0 activerecord_unittest2"

# Create MySQL database and databases
MYSQL_PWD=root sudo mysql -uroot <<SQL
CREATE USER 'rails'@'localhost';
CREATE DATABASE activerecord_unittest  DEFAULT CHARACTER SET utf8mb4;
CREATE DATABASE activerecord_unittest2 DEFAULT CHARACTER SET utf8mb4;
GRANT ALL PRIVILEGES ON activerecord_unittest.* to 'rails'@'localhost';
GRANT ALL PRIVILEGES ON activerecord_unittest2.* to 'rails'@'localhost';
GRANT ALL PRIVILEGES ON inexistent_activerecord_unittest.* to 'rails'@'localhost';
SQL
