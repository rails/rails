**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

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

### Install Additional Tools and Services

Some Rails tests depend on additional tools that you need to install before running those specific tests.

Here's the list of each gems' additional dependencies:

* Action Cable depends on Redis
* Active Record depends on SQLite3, MySQL and PostgreSQL
* Active Storage depends on Yarn (additionally Yarn depends on [Node.js](https://nodejs.org/))
* Active Support depends on memcached and Redis
* Railties depend on a JavaScript runtime environment, such as having [Node.js](https://nodejs.org/) installed.

Install all the services you need to properly test the full gem you'll be making changes to.
For example, if you will make changes to Action Cable, you _must_ install Redis, in order to be able to run all Action Cable tests before submitting your pull request.

NOTE: Redis' documentation discourage installations with package managers as those are usually outdated. Installing from source and bringing the server up is straight forward and well documented on [Redis' documentation](https://redis.io/download#installation).

NOTE: Active Record's test suite runs three times: once for SQLite3, once for MySQL, and once for PostgreSQL. We are going to see now how to set up the environment for them.

NOTE: Extracting previews, tested in Active Storage's test suite requires third-party applications:
ImageMagick for images, FFmpeg for video and muPDF for PDFs, and on macOS also XQuartz and Poppler.
Without these applications installed, Active Storage tests will raise errors.

WARNING: If you're working with Active Record code, you _must_ ensure that the tests pass for at least MySQL, PostgreSQL, and SQLite3. Subtle differences between the various adapters have been behind the rejection of many patches that looked OK when tested only against single adapter.

Below you can find instructions on how to install all of the additional tools for different OSes.

#### macOS

On macOS you can use [Homebrew](https://brew.sh/) to install all of the additional tools.

To install all run:

```bash
$ brew install sqlite3 mysql postgresql redis memcached yarn imagemagick ffmpeg mupdf-tools poppler
$ brew cask install xquartz
```

You'll also need to start each of the installed services. To list all available services run:

```bash
$ brew services list
```

You can then start each of the services one by one like this:

```bash
$ brew services start mysql
```

Replace `mysql` with the name of the service you want to start.

#### Ubuntu

To install all run:

```bash
$ sudo apt-get update
$ sudo apt-get install sqlite3 libsqlite3-dev mysql-server libmysqlclient-dev postgresql postgresql-client postgresql-contrib libpq-dev redis-server memcached imagemagick ffmpeg mupdf mupdf-tools
# install yarn
$ curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
$ echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
$ sudo apt-get install yarn
```

#### Fedora or CentOS

To install all run:

```bash
$ sudo yum install libsqlite3x libsqlite3x-devel mysql-server mysql-devel postgresql-server postgresql-devel redis memcached imagemagick ffmpeg mupdf
# install yarn
$ sudo wget https://dl.yarnpkg.com/rpm/yarn.repo -O /etc/yum.repos.d/yarn.repo
$ sudo yum install yarn
```

#### Arch Linux

To install all run:

```bash
$ sudo pacman -S sqlite mariadb libmariadbclient mariadb-clients postgresql postgresql-libs redis memcached imagemagick ffmpeg mupdf mupdf-tools poppler
$ sudo systemctl start redis
```

NOTE: If you are running Arch Linux, MySQL isn't supported anymore so you will need to
use MariaDB instead (see [this announcement](https://www.archlinux.org/news/mariadb-replaces-mysql-in-repositories/)).

#### FreeBSD

To install all run:

```bash
# pkg install sqlite3 mysql56-client mysql56-server postgresql94-client postgresql94-server memcached imagemagick ffmpeg mupdf
# portmaster databases/redis
```

Or install everyting through ports (these packages are located under the `databases` folder).

NOTE: If you run into troubles during the installation of MySQL, please see
[the MySQL documentation](http://dev.mysql.com/doc/refman/5.1/en/freebsd-installation.html).

### Database Configuration

There are couple of additional steps required to configure database engines required for running Active Record tests.

In order to be able to run the test suite against MySQL you need to create a user named `rails` with privileges on the test databases:

```bash
$ mysql -uroot -p

mysql> CREATE USER 'rails'@'localhost';
mysql> GRANT ALL PRIVILEGES ON activerecord_unittest.* to 'rails'@'localhost';
mysql> GRANT ALL PRIVILEGES ON activerecord_unittest2.* to 'rails'@'localhost';
mysql> GRANT ALL PRIVILEGES ON inexistent_activerecord_unittest.* to 'rails'@'localhost';
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

Then, you need to create the test databases for both MySQL and PostgreSQL with:

```bash
$ cd activerecord
$ bundle exec rake db:create
```

NOTE: You'll see the following warning (or localized warning) during activating HStore extension in PostgreSQL 9.1.x or earlier: "WARNING: => is deprecated as an operator".

You can also create test databases for each database engine separately:

```bash
$ cd activerecord
$ bundle exec rake db:mysql:build
$ bundle exec rake db:postgresql:build
```

and you can drop the databases using:

```bash
$ cd activerecord
$ bundle exec rake db:drop
```

NOTE: Using the Rake task to create the test databases ensures they have the correct character set and collation.

If you're using another database, check the file `activerecord/test/config.yml` or `activerecord/test/config.example.yml` for default connection information. You can edit `activerecord/test/config.yml` to provide different credentials on your machine if you must, but obviously you should not push any such changes back to Rails.

### Install JavaScript dependencies

If you installed Yarn, you will need to install the javascript dependencies:

```bash
$ cd activestorage
$ yarn install
```

### Install Bundler gem

Get a recent version of [Bundler](https://bundler.io/)

```bash
$ gem install bundler
$ gem update bundler
```

and run:

```bash
$ bundle install
```

or:

```bash
$ bundle install --without db
```

if you don't need to run Active Record tests.

### Contribute to Rails

After you've setup everything, read how you can start [contributing](contributing_to_ruby_on_rails.html#running-an-application-against-your-local-branch).
