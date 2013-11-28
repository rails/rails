Ruby on Rails 4.1 Release Notes
===============================

Highlights in Rails 4.1:

* ...
* ...

These release notes cover only the major changes. To know about various bug
fixes and changes, please refer to the change logs or check out the
[list of commits](https://github.com/rails/rails/commits/master) in the main
Rails repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 4.1
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 4.0 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 4.1. A list of things to watch out for when upgrading is
available in the
[Upgrading to Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-4-0-to-rails-4-1)
guide.

Creating a Rails 4.1 application
--------------------------------

```
You should have the 'rails' RubyGem installed
$ rails new myapp
$ cd myapp
```

### Vendoring Gems

Rails uses a `Gemfile` in the application root to determine the gems you require
for your application to start. This `Gemfile` is processed by the
[Bundler](https://github.com/carlhuda/bundler) gem, which then installs all your
dependencies. It can even install all the dependencies locally to your
application so that it doesn't depend on the system gems.

More information: [Bundler homepage](http://gembundler.com)

### Living on the Edge

`Bundler` and `Gemfile` makes freezing your Rails application easy as pie with
the new dedicated `bundle` command. If you want to bundle straight from the Git
repository, you can pass the `--edge` flag:

```
$ rails new myapp --edge
```

If you have a local checkout of the Rails repository and want to generate an
application using that, you can pass the `--dev` flag:

```
$ ruby /path/to/rails/railties/bin/rails new myapp --dev
```

Major Features
--------------


Documentation
-------------


Railties
--------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/railties/CHANGELOG.md)
for detailed changes.

### Notable changes


Action Mailer
-------------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/actionmailer/CHANGELOG.md)
for detailed changes.

### Notable changes


Active Model
------------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/activemodel/CHANGELOG.md)
for detailed changes.

### Notable changes


Active Support
--------------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/activesupport/CHANGELOG.md)
for detailed changes.

### Notable changes


Action Pack
-----------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/actionpack/CHANGELOG.md)
for detailed changes.

### Notable changes


Active Record
-------------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/activerecord/CHANGELOG.md)
for detailed changes.

### Notable changes


Credits
-------

See the
[full list of contributors to Rails](http://contributors.rubyonrails.org/) for
the many people who spent many hours making Rails, the stable and robust
framework it is. Kudos to all of them.
