**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Ruby on Rails 5.0 Release Notes
===============================

Highlights in Rails 5.0:

* Action Cable
* Rails API
* Active Rcord Attributes API
* Test Runner
* Exclusive use of `rails` CLI over Rake
* Sprockets 3
* Turbolinks 5
* Ruby 2.2.2+ required

These release notes cover only the major changes. To learn about various bug
fixes and changes, please refer to the change logs or check out the [list of
commits](https://github.com/rails/rails/commits/5-0-stable) in the main Rails
repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 5.0
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 4.2 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 5.0. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-4-2-to-rails-5-0)
guide.


Major Features
--------------

### Action Cable
[Pull Request](https://github.com/rails/rails/pull/22586)

ToDo...

### Rails API
[Pull Request](https://github.com/rails/rails/pull/19832)

ToDo...

### Active Record attributes API

ToDo...

### Test Runner
[Pull Request](https://github.com/rails/rails/pull/19216)

ToDo...


Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

*   Removed debugger supprt use byebug instead. `debugger` is not supported by
    Ruby
    2.2. ([commit](https://github.com/rails/rails/commit/93559da4826546d07014f8cfa399b64b4a143127))

*   Remove deprecated `test:all` and `test:all:db` tasks.
    ([commit](https://github.com/rails/rails/commit/f663132eef0e5d96bf2a58cec9f7c856db20be7c))

*   Remove deprecated `Rails::Rack::LogTailer`.
    ([commit](https://github.com/rails/rails/commit/c564dcb75c191ab3d21cc6f920998b0d6fbca623))

*   Remove deprecated `RAILS_CACHE` constant.
    ([commit](https://github.com/rails/rails/commit/b7f856ce488ef8f6bf4c12bb549f462cb7671c08))

*   Remove deprecated `serve_static_assets` configuration.
    ([commit](https://github.com/rails/rails/commit/463b5d7581ee16bfaddf34ca349b7d1b5878097c))

*   Remove the documentation tasks `doc:app`, `doc:rails`, and `doc:guides`.
    ([commit](https://github.com/rails/rails/commit/cd7cc5254b090ccbb84dcee4408a5acede25ef2a))

### Deprecations

*   Deprecate `config.static_cache_control` in favor of
    `config.public_file_server.headers`.
    ([Pull Request](https://github.com/rails/rails/pull/22173))

*   Deprecate `config.serve_static_files` in favor of `config.public_file_server.enabled`.
    ([Pull Request](https://github.com/rails/rails/pull/22173))

### Notable changes

*   Added Rails test runner `bin/rails test`.
    ([Pull Request](https://github.com/rails/rails/pull/19216))

*   Newly generated applications and plugins get a `README.md` in Markdown.
    ([commit](https://github.com/rails/rails/commit/89a12c931b1f00b90e74afffcdc2fc21f14ca663),
     [Pull Request](https://github.com/rails/rails/pull/22068))

*   Added `bin/rails restart` task to restart your Rails app by touching `tmp/restart.txt`.
    ([Pull Request](https://github.com/rails/rails/pull/18965))

*   Added `bin/rails initializers` task to print out all defined initializers in
    the order they are invoked by Rails.
    ([Pull Request](https://github.com/rails/rails/pull/19323))

*   Removed `Rack::ContentLength` middleware from the default
    stack. ([Commit](https://github.com/rails/rails/commit/56903585a099ab67a7acfaaef0a02db8fe80c450))

*   Added `bin/rails dev:cache` to enable or disable caching in development mode.
    ([Pull Request](https://github.com/rails/rails/pull/20961))

*   Added `bin/update` script to update the development environment automatically.
    ([Pull Request](https://github.com/rails/rails/pull/20972))

*   Proxy Rake tasks through `bin/rails`.
    ([Pull Request](https://github.com/rails/rails/pull/22457),
     [Pull Request](https://github.com/rails/rails/pull/22288))


Action Pack
-----------

Please refer to the [Changelog][action-pack] for detailed changes.

### Removals

*   Removed `ActionDispatch::Request::Utils.deep_munge`.
    ([commit](https://github.com/rails/rails/commit/52cf1a71b393486435fab4386a8663b146608996))

### Deprecations

### Notable changes

*   Make `ActionController::Parameters` no longer inherits from
    `HashWithIndifferentAccess`.
    ([Pull Request](https://github.com/rails/rails/pull/20868))

Action View
-------------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

### Deprecations

### Notable Changes

*   Support explicit definition of resouce name for collection caching.
    ([Pull Request](https://github.com/rails/rails/pull/20781))

*   Make `disable_with` default in `submit_tag`.
    ([Pull Request](https://github.com/rails/rails/pull/21135))


Action Mailer
-------------

Please refer to the [Changelog][action-mailer] for detailed changes.

### Removals

### Deprecations

### Notable changes


Active Record
-------------

Please refer to the [Changelog][active-record] for detailed changes.

### Removals

### Deprecations

*   Deprecated returning `false` as a way to halt Active Record callback
    chains. The recommended way is to
    `throw(:abort)`. ([Pull Request](https://github.com/rails/rails/pull/17227))

*   Synchronize behavior of `#tables`.
    ([Pull Request](https://github.com/rails/rails/pull/21601))

*   Deprecate `connection.tables` on the SQLite3 and MySQL adapters.

*   Deprecate passing arguments to `#tables` - the `#tables` method of some
    adapters (mysql2, sqlite3) would return both tables and views while others
    (postgresql) just return tables. To make their behavior consistent,
    `#tables` will return only tables in the future.

*   Deprecate `table_exists?` - The `#table_exists?` method would check both
    tables and views. To make their behavior consistent with `#tables`,
    `#table_exists?` will check only tables in the future.

### Notable changes

*   Add a `foreign_key` option to `references` while creating the table.
    ([commit](https://github.com/rails/rails/commit/99a6f9e60ea55924b44f894a16f8de0162cf2702))

*   New attributes
    API. ([commit](https://github.com/rails/rails/commit/8c752c7ac739d5a86d4136ab1e9d0142c4041e58))

*   Add `:enum_prefix`/`:enum_suffix` option to `enum`
    definition. ([Pull Request](https://github.com/rails/rails/pull/19813))

*   Add `#cache_key` to `ActiveRecord::Relation`.
    ([Pull Request](https://github.com/rails/rails/pull/20884))

*   Add `ActiveRecord::Relation#outer_joins`.
    ([Pull Request](https://github.com/rails/rails/pull/12071))

*   Require `belongs_to` by default.
    ([Pull Request](https://github.com/rails/rails/pull/18937)) - Deprecate
    `required` option in favor of `optional` for `belongs_to`


Active Model
------------

Please refer to the [Changelog][active-model] for detailed changes.

### Removals

*   Removed XML serialization. This feature has been extracted into the
    [activemodel-serializers-xml](https://github.com/rails/activemodel-serializers-xml) gem.
    ([Pull Request](https://github.com/rails/rails/pull/21161))

### Deprecations

*   Deprecated returning `false` as a way to halt Active Model and
    `ActiveModel::Valdiations` callback chains. The recommended way is to
    `throw(:abort)`. ([Pull Request](https://github.com/rails/rails/pull/17227))

### Notable changes

*   Validate multiple contexts on `valid?` and `invalid?` at once.
    ([Pull Request](https://github.com/rails/rails/pull/21069))


Active Job
-----------

Please refer to the [Changelog][active-job] for detailed changes.

### Removals

### Deprecations

### Notable changes


Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

### Removals

### Deprecations

*   Replace `ActiveSupport::Concurrency::Latch` with
    `Concurrent::CountDownLatch` from concurrent-ruby.
    ([Pull Request](https://github.com/rails/rails/pull/20866))

### Notable changes

*   New config option
    `config.active_support.halt_callback_chains_on_return_false` to specify
    whether ActiveRecord, ActiveModel and ActiveModel::Validations callback
    chains can be halted by returning `false` in a 'before' callback.
    ([Pull Request](https://github.com/rails/rails/pull/17227))


Credits
-------

See the
[full list of contributors to Rails](http://contributors.rubyonrails.org/) for
the many people who spent many hours making Rails, the stable and robust
framework it is. Kudos to all of them.

[railties]:       https://github.com/rails/rails/blob/5-0-stable/railties/CHANGELOG.md
[action-pack]:    https://github.com/rails/rails/blob/5-0-stable/actionpack/CHANGELOG.md
[action-view]:    https://github.com/rails/rails/blob/5-0-stable/actionview/CHANGELOG.md
[action-mailer]:  https://github.com/rails/rails/blob/5-0-stable/actionmailer/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/5-0-stable/activerecord/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/5-0-stable/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/5-0-stable/activesupport/CHANGELOG.md
[active-job]:     https://github.com/rails/rails/blob/5-0-stable/activejob/CHANGELOG.md
