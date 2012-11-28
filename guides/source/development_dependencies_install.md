Development Dependencies Install
================================

This guide covers how to setup an environment for Ruby on Rails core development.

--------------------------------------------------------------------------------

The Easy Way
------------

The easiest and recommended way to get a development environment ready to hack is to use the [Rails development box](https://github.com/rails/rails-dev-box).

The Hard Way
------------

In case you can't use the Rails development box, see section above, these are the steps to manually build a development box for Ruby on Rails core development.

### Install Git

Ruby on Rails uses Git for source code control. The [Git homepage](http://git-scm.com/) has installation instructions. There are a variety of resources on the net that will help you get familiar with Git:

* [Try Git course](http://try.github.com/) is an interactive course that will teach you the basics.
* The [official Documentation](http://git-scm.com/documentation) is pretty comprehensive and also contains some videos with the basics of Git
* [Everyday Git](http://schacon.github.com/git/everyday.html) will teach you just enough about Git to get by.
* The [PeepCode screencast](https://peepcode.com/products/git) on Git ($9) is easier to follow.
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

Install first libxml2 and libxslt together with their development files for Nokogiri. In Ubuntu that's

```bash
$ sudo apt-get install libxml2 libxml2-dev libxslt1-dev
```

If you are on Fedora or CentOS, you can run

```bash
$ sudo yum install libxml2 libxml2-devel libxslt libxslt-devel
```

If you have any problems with these libraries, you should install them manually compiling the source code. Just follow the instructions at the [Red Hat/CentOS section of the Nokogiri tutorials](http://nokogiri.org/tutorials/installing_nokogiri.html#red_hat__centos) .

Also, SQLite3 and its development files for the `sqlite3-ruby` gem — in Ubuntu you're done with just

```bash
$ sudo apt-get install sqlite3 libsqlite3-dev
```

And if you are on Fedora or CentOS, you're done with

```bash
$ sudo yum install sqlite3 sqlite3-devel
```

Get a recent version of [Bundler](http://gembundler.com/)

```bash
$ gem install bundler
$ gem update bundler
```

and run:

```bash
$ bundle install --without db
```

This command will install all dependencies except the MySQL and PostgreSQL Ruby drivers. We will come back to these soon. With dependencies installed, you can run the test suite with:

```bash
$ bundle exec rake test
```

You can also run tests for a specific component, like Action Pack, by going into its directory and executing the same command:

```bash
$ cd actionpack
$ bundle exec rake test
```

If you want to run the tests located in a specific directory use the `TEST_DIR` environment variable. For example, this will run the tests of the `railties/test/generators` directory only:

```bash
$ cd railties
$ TEST_DIR=generators bundle exec rake test
```

You can run any single test separately too:

```bash
$ cd actionpack
$ bundle exec ruby -Itest test/template/form_helper_test.rb
```

### Active Record Setup

The test suite of Active Record attempts to run four times: once for SQLite3, once for each of the two MySQL gems (`mysql` and `mysql2`), and once for PostgreSQL. We are going to see now how to set up the environment for them.

WARNING: If you're working with Active Record code, you _must_ ensure that the tests pass for at least MySQL, PostgreSQL, and SQLite3. Subtle differences between the various adapters have been behind the rejection of many patches that looked OK when tested only against MySQL.

#### Database Configuration

The Active Record test suite requires a custom config file: `activerecord/test/config.yml`. An example is provided in `activerecord/test/config.example.yml` which can be copied and used as needed for your environment.

#### MySQL and PostgreSQL

To be able to run the suite for MySQL and PostgreSQL we need their gems. Install first the servers, their client libraries, and their development files. In Ubuntu just run

```bash
$ sudo apt-get install mysql-server libmysqlclient15-dev
$ sudo apt-get install postgresql postgresql-client postgresql-contrib libpq-dev
```

On Fedora or CentOS, just run:

```bash
$ sudo yum install mysql-server mysql-devel
$ sudo yum install postgresql-server postgresql-devel
```

After that run:

```bash
$ rm .bundle/config
$ bundle install
```

We need first to delete `.bundle/config` because Bundler remembers in that file that we didn't want to install the "db" group (alternatively you can edit the file).

In order to be able to run the test suite against MySQL you need to create a user named `rails` with privileges on the test databases:

```bash
mysql> GRANT ALL PRIVILEGES ON activerecord_unittest.*
       to 'rails'@'localhost';
mysql> GRANT ALL PRIVILEGES ON activerecord_unittest2.*
       to 'rails'@'localhost';
```

and create the test databases:

```bash
$ cd activerecord
$ bundle exec rake mysql:build_databases
```

PostgreSQL's authentication works differently. A simple way to set up the development environment for example is to run with your development account

```bash
$ sudo -u postgres createuser --superuser $USER
```

and then create the test databases with

```bash
$ cd activerecord
$ bundle exec rake postgresql:build_databases
```

NOTE: Using the rake task to create the test databases ensures they have the correct character set and collation.

NOTE: You'll see the following warning (or localized warning) during activating HStore extension in PostgreSQL 9.1.x or earlier: "WARNING: => is deprecated as an operator".

If you’re using another database, check the file `activerecord/test/config.yml` or `activerecord/test/config.example.yml` for default connection information. You can edit `activerecord/test/config.yml` to provide different credentials on your machine if you must, but obviously you should not push any such changes back to Rails.
