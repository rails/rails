Development Dependencies Install
================================

This guide covers how to setup an environment for Ruby on Rails core development.

After reading this guide, you will know:

* How to set up your machine for Rails development
* How to run specific groups of unit tests from the Rails test suite
* How the ActiveRecord portion of the Rails test suite operates

--------------------------------------------------------------------------------

The Easy Way
------------

The easiest and recommended way to get a development environment ready to hack is to use the [Rails development box](https://github.com/rails/rails-dev-box).

The Hard Way
------------

In case you can't use the Rails development box, see section above, these are the steps to manually build a development box for Ruby on Rails core development.

### Install Git

Ruby on Rails uses Git for source code control. The [Git homepage](http://git-scm.com/) has installation instructions. There are a variety of resources on the net that will help you get familiar with Git:

* [Try Git course](http://try.github.io/) is an interactive course that will teach you the basics.
* The [official Documentation](http://git-scm.com/documentation) is pretty comprehensive and also contains some videos with the basics of Git
* [Everyday Git](http://schacon.github.io/git/everyday.html) will teach you just enough about Git to get by.
* The [PeepCode screencast](https://peepcode.com/products/git) on Git is easier to follow.
* [GitHub](http://help.github.com) offers links to a variety of Git resources.
* [Pro Git](http://git-scm.com/book) is an entire book about Git with a Creative Commons license.

### Clone the Ruby on Rails Repository

Navigate to the folder where you want the Ruby on Rails source code (it will create its own `rails` subdirectory) and run:

```bash
$ git clone git://github.com/rails/rails.git
$ cd rails
```

### Set up and Run the Tests

The test suite must pass with any submitted code. No matter whether you are writing a new patch, or evaluating someone else's, you need to be able to run the tests.

Install first SQLite3 and its development files for the `sqlite3` gem. Mac OS X
users are done with:

```bash
$ brew install sqlite3
```

In Ubuntu you're done with just:

```bash
$ sudo apt-get install sqlite3 libsqlite3-dev
```

And if you are on Fedora or CentOS, you're done with

```bash
$ sudo yum install sqlite3 sqlite3-devel
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

Get a recent version of [Bundler](http://bundler.io/)

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

You can use [Homebrew](http://brew.sh/) to install memcached on OS X:

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

### Active Record Setup

The test suite of Active Record attempts to run four times: once for SQLite3, once for each of the two MySQL gems (`mysql` and `mysql2`), and once for PostgreSQL. We are going to see now how to set up the environment for them.

WARNING: If you're working with Active Record code, you _must_ ensure that the tests pass for at least MySQL, PostgreSQL, and SQLite3. Subtle differences between the various adapters have been behind the rejection of many patches that looked OK when tested only against MySQL.

#### Database Configuration

The Active Record test suite requires a custom config file: `activerecord/test/config.yml`. An example is provided in `activerecord/test/config.example.yml` which can be copied and used as needed for your environment.

#### MySQL and PostgreSQL

To be able to run the suite for MySQL and PostgreSQL we need their gems. Install
first the servers, their client libraries, and their development files.

On OS X, you can run:

```bash
$ brew install mysql
$ brew install postgresql
```

Follow the instructions given by Homebrew to start these.

In Ubuntu just run:

```bash
$ sudo apt-get install mysql-server libmysqlclient15-dev
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
# pkg install postgresql93-client postgresql93-server
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

and for OS X:

```bash
$ createuser --superuser $USER
```

Then you need to create the test databases with

```bash
$ cd activerecord
$ bundle exec rake db:postgresql:build
```

It is possible to build databases for both PostgreSQL and MySQL with

```bash
$ cd activerecord
$ bundle exec rake db:create
```

You can cleanup the databases using

```bash
$ cd activerecord
$ bundle exec rake db:drop
```

NOTE: Using the rake task to create the test databases ensures they have the correct character set and collation.

NOTE: You'll see the following warning (or localized warning) during activating HStore extension in PostgreSQL 9.1.x or earlier: "WARNING: => is deprecated as an operator".

If you're using another database, check the file `activerecord/test/config.yml` or `activerecord/test/config.example.yml` for default connection information. You can edit `activerecord/test/config.yml` to provide different credentials on your machine if you must, but obviously you should not push any such changes back to Rails.
