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

*   Removed deprecated `test:all` and `test:all:db` tasks.
    ([commit](https://github.com/rails/rails/commit/f663132eef0e5d96bf2a58cec9f7c856db20be7c))

*   Removed deprecated `Rails::Rack::LogTailer`.
    ([commit](https://github.com/rails/rails/commit/c564dcb75c191ab3d21cc6f920998b0d6fbca623))

*   Removed deprecated `RAILS_CACHE` constant.
    ([commit](https://github.com/rails/rails/commit/b7f856ce488ef8f6bf4c12bb549f462cb7671c08))

*   Removed deprecated `serve_static_assets` configuration.
    ([commit](https://github.com/rails/rails/commit/463b5d7581ee16bfaddf34ca349b7d1b5878097c))

*   Removed the documentation tasks `doc:app`, `doc:rails`, and `doc:guides`.
    ([commit](https://github.com/rails/rails/commit/cd7cc5254b090ccbb84dcee4408a5acede25ef2a))

### Deprecations

*   Deprecated `config.static_cache_control` in favor of
    `config.public_file_server.headers`.
    ([Pull Request](https://github.com/rails/rails/pull/22173))

*   Deprecated `config.serve_static_files` in favor of `config.public_file_server.enabled`.
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

*   Removed `ActionController::HideActions`.
    ([Pull Request](https://github.com/rails/rails/pull/18371))

*   Removed `respond_to` and `respond_with` placeholder methods, this functionality
    has been extracted to the
    [responders](https://github.com/plataformatec/responders) gem.
    ([commit](https://github.com/rails/rails/commit/afd5e9a7ff0072e482b0b0e8e238d21b070b6280))

*   Removed deprecated assertion files.
    ([commit](https://github.com/rails/rails/commit/92e27d30d8112962ee068f7b14aa7b10daf0c976))

*   Removed deprecated usage of string keys in URL helpers.
    ([commit](https://github.com/rails/rails/commit/34e380764edede47f7ebe0c7671d6f9c9dc7e809))

*   Removed deprecated `only_path` option on `*_path` helpers.
    ([commit](https://github.com/rails/rails/commit/e4e1fd7ade47771067177254cb133564a3422b8a))

*   Removed deprecated `NamedRouteCollection#helpers`.
    ([commit](https://github.com/rails/rails/commit/2cc91c37bc2e32b7a04b2d782fb8f4a69a14503f))

*   Removed deprecated support to define routes with `:to` option that doesn't contain `#`.
    ([commit](https://github.com/rails/rails/commit/1f3b0a8609c00278b9a10076040ac9c90a9cc4a6))

*   Removed deprecated `ActionDispatch::Response#to_ary`.
    ([commit](https://github.com/rails/rails/commit/4b19d5b7bcdf4f11bd1e2e9ed2149a958e338c01))

*   Removed deprecated `ActionDispatch::Request#deep_munge`.
    ([commit](https://github.com/rails/rails/commit/7676659633057dacd97b8da66e0d9119809b343e))

*   Removed deprecated
    `ActionDispatch::Http::Parameters#symbolized_path_parameters`.
    ([commit](https://github.com/rails/rails/commit/7fe7973cd8bd119b724d72c5f617cf94c18edf9e))

*   Removed deprecated option `use_route` in controller tests.
    ([commit](https://github.com/rails/rails/commit/e4cfd353a47369dd32198b0e67b8cbb2f9a1c548))

*   Removed `assigns` and `assert_template`. Both methods have been extracted
    into the
    [rails-controller-testing](https://github.com/rails/rails-controller-testing)
    gem.
    ([Pull Request](https://github.com/rails/rails/pull/20138))

### Deprecations

*   Deprecated all `*_filter` callbacks in favor of `*_action` callbacks.
    ([Pull Request](https://github.com/rails/rails/pull/18410))

*   Deprecated `*_via_redirect` integration test methods. Use `follow_redirect!`
    manually after the request call for the same behavior.
    ([Pull Request](https://github.com/rails/rails/pull/18693))

*   Deprecated `AbstractController#skip_action_callback` in favor of individual
    skip_callback methods.
    ([Pull Request](https://github.com/rails/rails/pull/19060))

*   Deprecated `:nothing` option for `render` method.
    ([Pull Request](https://github.com/rails/rails/pull/20336))

*   Deprecated passing first parameter as `Hash` and default status code for
    `head` method.
    ([Pull Request](https://github.com/rails/rails/pull/20407))

*   Deprecated using strings or symbols for middleware class names. Use class
    names instead.
    ([commit](https://github.com/rails/rails/commit/83b767ce))

*   Deprecated accessing mime types via constants (eg. `Mime::HTML`). Use the
    subscript operator with a symbol instead (eg. `Mime[:html]`).
    ([Pull Request](https://github.com/rails/rails/pull/21869))

*   Deprecated `redirect_to :back` in favor of `redirect_back`, which accepts a
    required `fallback_location` argument, thus eliminating the possibility of a
    `RedirectBackError`.
    ([Pull Request](https://github.com/rails/rails/pull/22506))

### Notable changes

*   Added `ActionController::Renderer` to render arbitrary templates
    outside controller actions.
    ([Pull Request](https://github.com/rails/rails/pull/18546))

*   Migrating to keyword arguments syntax in `ActionController::TestCase` and
    `ActionDispatch::Integration` HTTP request methods.
    ([Pull Request](https://github.com/rails/rails/pull/18323))

*   Added `http_cache_forever` to Action Controller, so we can cache a response
    that never gets expired.
    ([Pull Request](https://github.com/rails/rails/pull/18394))

*   Provide friendlier access to request variants.
    ([Pull Request](https://github.com/rails/rails/pull/18939))

*   For actions with no corresponding templates, render `head :no_content`
    instead of raising an error.
    ([Pull Request](https://github.com/rails/rails/pull/19377))

*   Added the ability to override default form builder for a controller.
    ([Pull Request](https://github.com/rails/rails/pull/19736))

*   Added support for API only apps.
    `ActionController::API` is added as a replacement of
    `ActionController::Base` for this kind of applications.
    ([Pull Request](https://github.com/rails/rails/pull/19832))

*   Make `ActionController::Parameters` no longer inherits from
    `HashWithIndifferentAccess`.
    ([Pull Request](https://github.com/rails/rails/pull/20868))

*   Make it easier to opt in to `config.force_ssl` and `config.ssl_options` by
    making them less dangerous to try and easier to disable.
    ([Pull Request](https://github.com/rails/rails/pull/21520))

*   Added the ability of returning arbitrary headers to `ActionDispatch::Static`.
    ([Pull Request](https://github.com/rails/rails/pull/19135))

*   Changed the `protect_from_forgery` prepend default to `false`.
    ([commit](https://github.com/rails/rails/commit/39794037817703575c35a75f1961b01b83791191))

*   `ActionController::TestCase` will be moved to it's own gem in Rails 5.1. Use
    `ActionDispatch::IntegrationTest` instead.
    ([commit](https://github.com/rails/rails/commit/4414c5d1795e815b102571425974a8b1d46d932d))

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

*   Deprecated `connection.tables` on the SQLite3 and MySQL adapters.

*   Deprecated passing arguments to `#tables` - the `#tables` method of some
    adapters (mysql2, sqlite3) would return both tables and views while others
    (postgresql) just return tables. To make their behavior consistent,
    `#tables` will return only tables in the future.

*   Deprecated `table_exists?` - The `#table_exists?` method would check both
    tables and views. To make their behavior consistent with `#tables`,
    `#table_exists?` will check only tables in the future.

### Notable changes

*   Added a `foreign_key` option to `references` while creating the table.
    ([commit](https://github.com/rails/rails/commit/99a6f9e60ea55924b44f894a16f8de0162cf2702))

*   New attributes
    API. ([commit](https://github.com/rails/rails/commit/8c752c7ac739d5a86d4136ab1e9d0142c4041e58))

*   Added `:enum_prefix`/`:enum_suffix` option to `enum`
    definition. ([Pull Request](https://github.com/rails/rails/pull/19813))

*   Added `#cache_key` to `ActiveRecord::Relation`.
    ([Pull Request](https://github.com/rails/rails/pull/20884))

*   Added `ActiveRecord::Relation#outer_joins`.
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
