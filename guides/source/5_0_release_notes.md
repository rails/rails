**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Ruby on Rails 5.0 Release Notes
===============================

Highlights in Rails 5.0:

* Ruby 2.2.2+ required
* ActionCable
* API Mode
* Exclusive use of `rails` CLI over Rake
* Sprockets 3
* Turbolinks 5

These release notes cover only the major changes. To learn about various bug
fixes and changes, please refer to the change logs or check out the [list of
commits](https://github.com/rails/rails/commits/5-0-stable) in the main Rails
repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 5.0
----------------------

If you're upgrading an existing application, it's a great idea to have good test coverage before going in. You should also first upgrade to Rails 4.2 in case you haven't and make sure your application still runs as expected before attempting an update to Rails 5.0. A list of things to watch out for when upgrading is available in the [Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-4-2-to-rails-5-0) guide.


Creating a Rails 5.0 application
--------------------------------

```
 You should have the 'rails' RubyGem installed
$ rails new myapp
$ cd myapp
```

### Living on the Edge

`Bundler` and `Gemfile` makes freezing your Rails application easy as pie with the new dedicated `bundle` command. If you want to bundle straight from the Git repository, you can pass the `--edge` flag:

```
$ rails new myapp --edge
```

If you have a local checkout of the Rails repository and want to generate an application using that, you can pass the `--dev` flag:

```
$ ruby /path/to/rails/railties/bin/rails new myapp --dev
```

Major Features
--------------

### Upgrade

* **Ruby 2.2.2** ([commit](https://github.com/rails/rails/commit/d3b098b8289ffaa8486f526dc53204123ed581f3)) - Ruby 2.2.2+ required
* **Rails API** ([commit](https://github.com/rails/rails/pull/19832)) - Rails API is merged directly into Rails
* **Make ActionController::Parameters not inherited from Hash** ([Pull Request](https://github.com/rails/rails/pull/20868))
* **Sprockets 3 is out** ([Upgrading Guide](https://github.com/rails/sprockets/blob/master/UPGRADING.md))

### General

* **Remove debugger supprt** ([commit](https://github.com/rails/rails/commit/93559da4826546d07014f8cfa399b64b4a143127)) - Debugger doesn't work with Ruby 2.2, so it is incompatible with Rails 5.0.
* **Deprecated returning `false` as a way to halt ActiveRecord callback chains.** ([Pull Request](https://github.com/rails/rails/pull/17227)) - The recommended way is to `throw(:abort)`. 

### Security

* Removal of `deep_munge` ([commit](https://github.com/rails/rails/commit/52cf1a71b393486435fab4386a8663b146608996)) - Now that we have encoding strategies, we can just walk the params hash
once to encode as HashWithIndifferentAccess, and remove nils.

Extraction of features to gems
---------------------------

In Rails 5.0, several features have been extracted into gems. You can simply add the extracted gems to your `Gemfile` to bring the functionality back.

* XML Serialization ([Github](https://github.com/rails/activemodel-serializers-xml), [Pull Request](https://github.com/rails/rails/pull/21161))

Action Cable
-------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/5-0-stable/actioncable/CHANGELOG.md) for detailed changes.

### Notable changes
* Initial public release, and merger into Rails ([Pull Request](https://github.com/rails/rails/pull/22586))

### Deprecations

Action Mailer
-------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/5-0-stable/actionmailer/CHANGELOG.md) for detailed changes.

### Notable changes

### Deprecations

Action Pack
-----------

Please refer to the [Changelog](https://github.com/rails/rails/blob/5-0-stable/actionpack/CHANGELOG.md) for detailed changes.

### Notable changes

### Deprecations

Action View
-------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/5-0-stable/actionview/CHANGELOG.md) for detailed changes.

### Notable Changes
* Support explicit definition of resouce name for collection caching ([Pull Request](https://github.com/rails/rails/pull/20781))
* Make `disable_with` default in `submit_tag` ([Pull Request](https://github.com/rails/rails/pull/21135))

### Deprecations

Active Job
-----------

Please refer to the [Changelog](https://github.com/rails/rails/blob/5-0-stable/activejob/CHANGELOG.md) for detailed changes.

### Notable changes

### Deprecations

Active Model
------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/5-0-stable/activemodel/CHANGELOG.md) for detailed changes.

### Notable changes
* Validate multiple contexts on `valid?` and `invalid?` at once ([Pull Request](https://github.com/rails/rails/pull/21069))

### Deprecations

* Deprecated returning `false` as a way to halt ActiveModel and ActiveModel::Valdiations callback chains. The recommended way is to `throw(:abort)`. ([Pull Request](https://github.com/rails/rails/pull/17227))

Active Record
-------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/5-0-stable/activerecord/CHANGELOG.md) for detailed changes.

### Notable changes

* Add a `foreign_key` option to `references` while creating the table ([commit](https://github.com/rails/rails/commit/99a6f9e60ea55924b44f894a16f8de0162cf2702))
* New attributes API ([commit](https://github.com/rails/rails/commit/8c752c7ac739d5a86d4136ab1e9d0142c4041e58))
* Add `:enum_prefix`/`:enum_suffix` option to `enum` definition. ([Pull Request](https://github.com/rails/rails/pull/19813))
* Add #cache_key to ActiveRecord::Relation ([Pull Request](https://github.com/rails/rails/pull/20884))
* Add `ActiveRecord::Relation#outer_joins` ([Pull Request](https://github.com/rails/rails/pull/12071))
* Require `belongs_to` by default ([Pull Request](https://github.com/rails/rails/pull/18937)) - Deprecate `required` option in favor of `optional` for `belongs_to`

### Deprecations

* Deprecated returning `false` as a way to halt ActiveRecord callback chains. The recommended way is to `throw(:abort)`. ([Pull Request](https://github.com/rails/rails/pull/17227))
* Synchronize behavior of `#tables` ([Pull Request](https://github.com/rails/rails/pull/21601))
  * Deprecate `connection.tables` on the SQLite3 and MySQL adapters.
  * Deprecate passing arguments to `#tables` - the `#tables` method of some adapters (mysql2, sqlite3) would return both tables and views while others (postgresql) just return tables. To make their behavior consistent, `#tables` will return only tables in the future.
  * Deprecate `table_exists?` - The `#table_exists?` method would check both tables and views. To make their behavior consistent with `#tables`, `#table_exists?` will check only tables in the future.

Active Support
--------------

Please refer to the [Changelog](https://github.com/rails/rails/blob/5-0-stable/activesupport/CHANGELOG.md) for detailed changes.

### Notable changes

* New config option `config.active_support.halt_callback_chains_on_return_false` to specify whether ActiveRecord, ActiveModel and ActiveModel::Validations callback chains can be halted by returning `false` in a 'before' callback.  ([Pull Request](https://github.com/rails/rails/pull/17227))

### Deprecations

* Replace `ActiveSupport::Concurrency::Latch` with `Concurrent::CountDownLatch` from concurrent-ruby ([Pull Request](https://github.com/rails/rails/pull/20866))

Railties
--------

Please refer to the [Changelog](https://github.com/rails/rails/blob/5-0-stable/railties/CHANGELOG.md) for detailed changes.

### Notable changes

* **Remove ContentLength middleware from defaults** ([Commit](https://github.com/rails/rails/commit/56903585a099ab67a7acfaaef0a02db8fe80c450)) - ContentLength is not part of the rack SPEC since [rack/rack@86ddc7a](https://github.com/rack/rack/commit/86ddc7a6ec68d7b6951c2dbd07947c4254e8bc0d). If you would like to use it, just add it as a middleware in your config.
* **Begin work on Rails test runner** ([Pull Request](https://github.com/rails/rails/pull/19216)) - Work has begun on a test runner that's built right into Rails. This pull requests lays the foundations for the runner.

### Deprecations

Credits
-------

See the [full list of contributors to Rails](http://contributors.rubyonrails.org/) for the many people who spent many hours making Rails, the stable and robust framework it is. Kudos to all of them.
