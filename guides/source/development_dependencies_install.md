**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Development Dependencies Install
================================

This guide covers how to setup an environment for Ruby on Rails core development.

After reading this guide, you will know:

* How to set up your machine for Rails development
* How to run specific groups of unit tests from the Rails test suite
* How the Active Record portion of the Rails test suite operates

--------------------------------------------------------------------------------

The Easy Way
------------

The easiest and recommended way to get a development environment ready to hack is to use the [Rails development box](https://github.com/rails/rails-dev-box).

The Hard Way
------------

In case you can't use the Rails development box, see the steps below to manually
build a development box for Ruby on Rails core development.

### Install Git

Ruby on Rails uses Git for source code control. The [Git homepage](https://git-scm.com/) has installation instructions. There are a variety of resources on the net that will help you get familiar with Git:

* [Try Git course](https://try.github.io/) is an interactive course that will teach you the basics.
* The [official Documentation](https://git-scm.com/documentation) is pretty comprehensive and also contains some videos with the basics of Git.
* [Everyday Git](https://schacon.github.io/git/everyday.html) will teach you just enough about Git to get by.
* [GitHub](https://help.github.com/) offers links to a variety of Git resources.
* [Pro Git](https://git-scm.com/book) is an entire book about Git with a Creative Commons license.

### Clone the Ruby on Rails Repository

Navigate to the folder where you want the Ruby on Rails source code (it will create its own `rails` subdirectory) and run:

```bash
$ git clone https://github.com/rails/rails.git
$ cd rails
```

### Set up and Run the Tests

The test suite must pass with any submitted code. No matter whether you are writing a new patch, or evaluating someone else's, you need to be able to run the tests.

Install first SQLite3 and its development files for the `sqlite3` gem. On macOS
users are done with:

```bash
$ brew install sqlite3
```

In Ubuntu you're done with just:

```bash
$ sudo apt-get install sqlite3 libsqlite3-dev
```

If you are on Fedora or CentOS, you're done with

```bash
$ sudo yum install libsqlite3x libsqlite3x-devel
```

If you are on Arch Linux, you will need to run:

```bash
$ sudo pacman -S sqlite
```

For FreeBSD users, you're done with:

```bash
# pkg install sqlite3
```

Or compile the `databases/sqlite3` port.

Get a recent version of [Bundler](https://bundler.io/)

```bash
$ gem install bundler
$ gem update bundler
```

and run:

```bash
$ bundle install --without db
```

This command will install all dependencies except the MySQL and PostgreSQL Ruby drivers. We will come back to these soon.

NOTE: If you would like to run the tests that use memcached, you need to ensure that you have it installed and running.

You can use [Homebrew](https://brew.sh/) to install memcached on macOS:

```bash
$ brew install memcached
```

On Ubuntu you can install it with apt-get:

```bash
$ sudo apt-get install memcached
```

Or use yum on Fedora or CentOS:

```bash
$ sudo yum install memcached
```

If you are running on Arch Linux:

```bash
$ sudo pacman -S memcached
```

For FreeBSD users, you're done with:

```bash
# pkg install memcached
```

Alternatively, you can compile the `databases/memcached` port.

With the dependencies now installed, you can run the test suite with:

```bash
$ bundle exec rake test
```

You can also run tests for a specific component, like Action Pack, by going into its directory and executing the same command:

```bash
$ cd actionpack
$ bundle exec rake test
```

If you want to run the tests located in a specific directory use the `TEST_DIR` environment variable. For example, this will run the tests in the `railties/test/generators` directory only:

```bash
$ cd railties
$ TEST_DIR=generators bundle exec rake test
```

You can run the tests for a particular file by using:

```bash
$ cd actionpack
$ bundle exec ruby -Itest test/template/form_helper_test.rb
```

Or, you can run a single test in a particular file:

```bash
$ cd actionpack
$ bundle exec ruby -Itest path/to/test.rb -n test_name
```

### Railties Setup

Some Railties tests depend on a JavaScript runtime environment, such as having [Node.js](https://nodejs.org/) installed.

### Active Record Setup

Active Record's test suite runs three times: once for SQLite3, once for MySQL, and once for PostgreSQL. We are going to see now how to set up the environment for them.

WARNING: If you're working with Active Record code, you _must_ ensure that the tests pass for at least MySQL, PostgreSQL, and SQLite3. Subtle differences between the various adapters have been behind the rejection of many patches that looked OK when tested only against MySQL.

#### Database Configuration

The Active Record test suite requires a custom config file: `activerecord/test/config.yml`. An example is provided in `activerecord/test/config.example.yml` which can be copied and used as needed for your environment.

#### MySQL and PostgreSQL

To be able to run the suite for MySQL and PostgreSQL we need their gems. Install
first the servers, their client libraries, and their development files.

On macOS, you can run:

```bash
$ brew install mysql
$ brew install postgresql
```

Follow the instructions given by Homebrew to start these.

On Ubuntu, just run:

```bash
$ sudo apt-get install mysql-server libmysqlclient-dev
$ sudo apt-get install postgresql postgresql-client postgresql-contrib libpq-dev
```

On Fedora or CentOS, just run:

```bash
$ sudo yum install mysql-server mysql-devel
$ sudo yum install postgresql-server postgresql-devel
```

If you are running Arch Linux, MySQL isn't supported anymore so you will need to
use MariaDB instead (see [this announcement](https://www.archlinux.org/news/mariadb-replaces-mysql-in-repositories/)):

```bash
$ sudo pacman -S mariadb libmariadbclient mariadb-clients
$ sudo pacman -S postgresql postgresql-libs
```

FreeBSD users will have to run the following:

```bash
# pkg install mysql56-client mysql56-server
# pkg install postgresql94-client postgresql94-server
```

Or install them through ports (they are located under the `databases` folder).
If you run into troubles during the installation of MySQL, please see
[the MySQL documentation](http://dev.mysql.com/doc/refman/5.1/en/freebsd-installation.html).

After that, run:

```bash
$ rm .bundle/config
$ bundle install
```

First, we need to delete `.bundle/config` because Bundler remembers in that file that we didn't want to install the "db" group (alternatively you can edit the file).

In order to be able to run the test suite against MySQL you need to create a user named `rails` with privileges on the test databases:

```bash
$ mysql -uroot -p

mysql> CREATE USER 'rails'@'localhost';
mysql> GRANT ALL PRIVILEGES ON activerecord_unittest.*
       to 'rails'@'localhost';
mysql> GRANT ALL PRIVILEGES ON activerecord_unittest2.*
       to 'rails'@'localhost';
mysql> GRANT ALL PRIVILEGES ON inexistent_activerecord_unittest.*
       to 'rails'@'localhost';
```

and create the test databases:

```bash
$ cd activerecord
$ bundle exec rake db:mysql:build
```

PostgreSQL's authentication works differently. To setup the development environment
with your development account, on Linux or BSD, you just have to run:

```bash
$ sudo -u postgres createuser --superuser $USER
```

and for macOS:

```bash
$ createuser --superuser $USER
```

Then, you need to create the test databases with:

```bash
$ cd activerecord
$ bundle exec rake db:postgresql:build
```

It is possible to build databases for both PostgreSQL and MySQL with:

```bash
$ cd activerecord
$ bundle exec rake db:create
```

You can cleanup the databases using:

```bash
$ cd activerecord
$ bundle exec rake db:drop
```

NOTE: Using the Rake task to create the test databases ensures they have the correct character set and collation.

NOTE: You'll see the following warning (or localized warning) during activating HStore extension in PostgreSQL 9.1.x or earlier: "WARNING: => is deprecated as an operator".

If you're using another database, check the file `activerecord/test/config.yml` or `activerecord/test/config.example.yml` for default connection information. You can edit `activerecord/test/config.yml` to provide different credentials on your machine if you must, but obviously you should not push any such changes back to Rails.

### Action Cable Setup

Action Cable uses Redis as its default subscriptions adapter ([read more](action_cable_overview.html#broadcasting)). Thus, in order to have Action Cable's tests passing you need to install and have Redis running.

#### Install Redis From Source

Redis' documentation discourage installations with package managers as those are usually outdated. Installing from source and bringing the server up is straight forward and well documented on [Redis' documentation](https://redis.io/download#installation).

#### Install Redis From Package Manager

On macOS, you can run:

```bash
$ brew install redis
```

Follow the instructions given by Homebrew to start these.

On Ubuntu, just run:

```bash
$ sudo apt-get install redis-server
```

On Fedora or CentOS (requires EPEL enabled), just run:

```bash
$ sudo yum install redis
```

If you are running Arch Linux, just run:

```bash
$ sudo pacman -S redis
$ sudo systemctl start redis
```

FreeBSD users will have to run the following:

```bash
# portmaster databases/redis
```

### Active Storage Setup

When working on Active Storage, it is important to note that you need to
install its JavaScript dependencies while working on that section of the
codebase. In order to install these dependencies, it is necessary to
have Yarn, a Node.js package manager, available on your system. A
prerequisite for installing this package manager is that
[Node.js](https://nodejs.org) is installed.


On macOS, you can run:

```bash
brew install yarn
```

On Ubuntu, you can run:

```bash
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

sudo apt-get update && sudo apt-get install yarn
```

On Fedora or CentOS, just run:

```bash
sudo wget https://dl.yarnpkg.com/rpm/yarn.repo -O /etc/yum.repos.d/yarn.repo

sudo yum install yarn
```

Finally, after installing Yarn, you will need to run the following
command inside of the `activestorage` directory to install the dependencies:

```bash
yarn install
```

Extracting previews, tested in ActiveStorage's test suite requires third-party
applications, FFmpeg for video and muPDF for PDFs, and on macOS also XQuartz
and Poppler. Without these applications installed, ActiveStorage tests will
raise errors.

On macOS you can run:

```bash
brew install ffmpeg
brew cask install xquartz
brew install mupdf-tools
brew install poppler
```

On Ubuntu, you can run:

```bash
sudo apt-get update && install ffmpeg
sudo apt-get update && install mupdf mupdf-tools
```

On Fedora or CentOS, just run:

```bash
sudo yum install ffmpeg
sudo yum install mupdf
```
