**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON http://guides.rubyonrails.org.**

Ruby on Rails 5.0 Release Notes
===============================

Highlights in Rails 5.0:

* Action Cable
* Rails API
* Active Record Attributes API
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

Action Cable is a new framework in Rails 5. It seamlessly integrates
[WebSockets](https://en.wikipedia.org/wiki/WebSocket) with the rest of your
Rails application.

Action Cable allows for real-time features to be written in Ruby in the
same style and form as the rest of your Rails application, while still being
performant and scalable. It's a full-stack offering that provides both a
client-side JavaScript framework and a server-side Ruby framework. You have
access to your full domain model written with Active Record or your ORM of
choice.

See the [Action Cable Overview](action_cable_overview.html) guide for more
information.

### API Applications

Rails can now be used to create slimmed down API only applications.
This is useful for creating and serving APIs similar to [Twitter](https://dev.twitter.com) or [GitHub](https://developer.github.com) API,
that can be used to serve public facing, as well as, for custom applications.

You can generate a new api Rails app using:

```bash
$ rails new my_api --api
```

This will do three main things:

- Configure your application to start with a more limited set of middleware
  than normal. Specifically, it will not include any middleware primarily useful
  for browser applications (like cookies support) by default.
- Make `ApplicationController` inherit from `ActionController::API` instead of
  `ActionController::Base`. As with middleware, this will leave out any Action
  Controller modules that provide functionalities primarily used by browser
  applications.
- Configure the generators to skip generating views, helpers, and assets when
  you generate a new resource.

The application provides a base for APIs,
that can then be [configured to pull in functionality](api_app.html) as suitable for the application's needs.

See the [Using Rails for API-only Applications](api_app.html) guide for more
information.

### Active Record attributes API

Defines an attribute with a type on a model. It will override the type of existing attributes if needed.
This allows control over how values are converted to and from SQL when assigned to a model.
It also changes the behavior of values passed to `ActiveRecord::Base.where`, which lets use our domain objects across much of Active Record,
without having to rely on implementation details or monkey patching.

Some things that you can achieve with this:

- The type detected by Active Record can be overridden.
- A default can also be provided.
- Attributes do not need to be backed by a database column.

```ruby

# db/schema.rb
create_table :store_listings, force: true do |t|
  t.decimal :price_in_cents
  t.string :my_string, default: "original default"
end

# app/models/store_listing.rb
class StoreListing < ActiveRecord::Base
end

store_listing = StoreListing.new(price_in_cents: '10.1')

# before
store_listing.price_in_cents # => BigDecimal.new(10.1)
StoreListing.new.my_string # => "original default"

class StoreListing < ActiveRecord::Base
  attribute :price_in_cents, :integer # custom type
  attribute :my_string, :string, default: "new default" # default value
  attribute :my_default_proc, :datetime, default: -> { Time.now } # default value
  attribute :field_without_db_column, :integer, array: true
end

# after
store_listing.price_in_cents # => 10
StoreListing.new.my_string # => "new default"
StoreListing.new.my_default_proc # => 2015-05-30 11:04:48 -0600
model = StoreListing.new(field_without_db_column: ["1", "2", "3"])
model.attributes # => {field_without_db_column: [1, 2, 3]}
```

**Creating Custom Types:**

You can define your own custom types, as long as they respond
to the methods defined on the value type. The method `deserialize` or
`cast` will be called on your type object, with raw input from the
database or from your controllers. This is useful, for example, when doing custom conversion,
like Money data.

**Querying:**

When `ActiveRecord::Base.where` is called, it will
use the type defined by the model class to convert the value to SQL,
calling `serialize` on your type object.

This gives the objects ability to specify, how to convert values when performing SQL queries.

**Dirty Tracking:**

The type of an attribute is given the opportunity to change how dirty
tracking is performed.

See its
[documentation](http://api.rubyonrails.org/v5.0.1/classes/ActiveRecord/Attributes/ClassMethods.html)
for a detailed write up.


### Test Runner

A new test runner has been introduced to enhance the capabilities of running tests from Rails.
To use this test runner simply type `bin/rails test`.

Test Runner is inspired from `RSpec`, `minitest-reporters`, `maxitest` and others.
It includes some of these notable advancements:

- Run a single test using line number of test.
- Run multiple tests pinpointing to line number of tests.
- Improved failure messages, which also add ease of re-running failed tests.
- Fail fast using `-f` option, to stop tests immediately on occurrence of failure,
instead of waiting for the suite to complete.
- Defer test output until the end of a full test run using the `-d` option.
- Complete exception backtrace output using `-b` option.
- Integration with `Minitest` to allow options like `-s` for test seed data,
`-n` for running specific test by name, `-v` for better verbose output and so forth.
- Colored test output.

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

*   Removed debugger support, use byebug instead. `debugger` is not supported by
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

*   Removed `Rack::ContentLength` middleware from the default
    stack. ([Commit](https://github.com/rails/rails/commit/56903585a099ab67a7acfaaef0a02db8fe80c450))

### Deprecations

*   Deprecated `config.static_cache_control` in favor of
    `config.public_file_server.headers`.
    ([Pull Request](https://github.com/rails/rails/pull/19135))

*   Deprecated `config.serve_static_files` in favor of `config.public_file_server.enabled`.
    ([Pull Request](https://github.com/rails/rails/pull/22173))

*   Deprecated the tasks in the `rails` task namespace in favor of the `app` namespace.
    (e.g. `rails:update` and `rails:template` tasks are renamed to `app:update` and `app:template`.)
    ([Pull Request](https://github.com/rails/rails/pull/23439))

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

*   Added `bin/rails dev:cache` to enable or disable caching in development mode.
    ([Pull Request](https://github.com/rails/rails/pull/20961))

*   Added `bin/update` script to update the development environment automatically.
    ([Pull Request](https://github.com/rails/rails/pull/20972))

*   Proxy Rake tasks through `bin/rails`.
    ([Pull Request](https://github.com/rails/rails/pull/22457),
     [Pull Request](https://github.com/rails/rails/pull/22288))

*   New applications are generated with the evented file system monitor enabled
    on Linux and macOS. The feature can be opted out by passing
    `--skip-listen` to the generator.
    ([commit](https://github.com/rails/rails/commit/de6ad5665d2679944a9ee9407826ba88395a1003),
    [commit](https://github.com/rails/rails/commit/94dbc48887bf39c241ee2ce1741ee680d773f202))

*   Generate applications with an option to log to STDOUT in production
    using the environment variable `RAILS_LOG_TO_STDOUT`.
    ([Pull Request](https://github.com/rails/rails/pull/23734))

*   Enable HSTS with IncludeSudomains header for new applications.
    ([Pull Request](https://github.com/rails/rails/pull/23852))

*   The application generator writes a new file `config/spring.rb`, which tells
    Spring to watch additional common files.
    ([commit](https://github.com/rails/rails/commit/b04d07337fd7bc17e88500e9d6bcd361885a45f8))

*   Added `--skip-action-mailer` to skip Action Mailer while generating new app.
    ([Pull Request](https://github.com/rails/rails/pull/18288))

*   Removed `tmp/sessions` directory and the clear rake task associated with it.
    ([Pull Request](https://github.com/rails/rails/pull/18314))

*   Changed `_form.html.erb` generated by scaffold generator to use local variables.
    ([Pull Request](https://github.com/rails/rails/pull/13434))

*   Disabled autoloading of classes in production environment.
    ([commit](https://github.com/rails/rails/commit/a71350cae0082193ad8c66d65ab62e8bb0b7853b))

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

*   `ActionDispatch::IntegrationTest` and `ActionController::TestCase` deprecate positional arguments in favor of
    keyword arguments. ([Pull Request](https://github.com/rails/rails/pull/18323))

*   Deprecated `:controller` and `:action` path parameters.
    ([Pull Request](https://github.com/rails/rails/pull/23980))

*   Deprecated env method on controller instances.
    ([commit](https://github.com/rails/rails/commit/05934d24aff62d66fc62621aa38dae6456e276be))

*   `ActionDispatch::ParamsParser` is deprecated and was removed from the
    middleware stack. To configure the parameter parsers use
    `ActionDispatch::Request.parameter_parsers=`.
    ([commit](https://github.com/rails/rails/commit/38d2bf5fd1f3e014f2397898d371c339baa627b1),
    [commit](https://github.com/rails/rails/commit/5ed38014811d4ce6d6f957510b9153938370173b))

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

*   `ActionController::TestCase` will be moved to its own gem in Rails 5.1. Use
    `ActionDispatch::IntegrationTest` instead.
    ([commit](https://github.com/rails/rails/commit/4414c5d1795e815b102571425974a8b1d46d932d))

*   Rails generates weak ETags by default.
    ([Pull Request](https://github.com/rails/rails/pull/17573))

*   Controller actions without an explicit `render` call and with no
    corresponding templates will render `head :no_content` implicitly
    instead of raising an error.
    (Pull Request [1](https://github.com/rails/rails/pull/19377),
    [2](https://github.com/rails/rails/pull/23827))

*   Added an option for per-form CSRF tokens.
    ([Pull Request](https://github.com/rails/rails/pull/22275))

*   Added request encoding and response parsing to integration tests.
    ([Pull Request](https://github.com/rails/rails/pull/21671))

*   Add `ActionController#helpers` to get access to the view context
    at the controller level.
    ([Pull Request](https://github.com/rails/rails/pull/24866))

*   Discarded flash messages get removed before storing into session.
    ([Pull Request](https://github.com/rails/rails/pull/18721))

*   Added support for passing collection of records to `fresh_when` and
    `stale?`.
    ([Pull Request](https://github.com/rails/rails/pull/18374))

*   `ActionController::Live` became an `ActiveSupport::Concern`. That
    means it can't be just included in other modules without extending
    them with `ActiveSupport::Concern` or `ActionController::Live`
    won't take effect in production. Some people may be using another
    module to include some special `Warden`/`Devise` authentication
    failure handling code as well since the middleware can't catch a
    `:warden` thrown by a spawned thread which is the case when using
    `ActionController::Live`.
    ([More details in this issue](https://github.com/rails/rails/issues/25581))

*   Introduce `Response#strong_etag=` and `#weak_etag=` and analogous
    options for `fresh_when` and `stale?`.
    ([Pull Request](https://github.com/rails/rails/pull/24387))

Action View
-------------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

*   Removed deprecated `AbstractController::Base::parent_prefixes`.
    ([commit](https://github.com/rails/rails/commit/34bcbcf35701ca44be559ff391535c0dd865c333))

*   Removed `ActionView::Helpers::RecordTagHelper`, this functionality
    has been extracted to the
    [record_tag_helper](https://github.com/rails/record_tag_helper) gem.
    ([Pull Request](https://github.com/rails/rails/pull/18411))

*   Removed `:rescue_format` option for `translate` helper since it's no longer
    supported by I18n.
    ([Pull Request](https://github.com/rails/rails/pull/20019))

### Notable Changes

*   Changed the default template handler from `ERB` to `Raw`.
    ([commit](https://github.com/rails/rails/commit/4be859f0fdf7b3059a28d03c279f03f5938efc80))

*   Collection rendering can cache and fetches multiple partials at once.
    ([Pull Request](https://github.com/rails/rails/pull/18948),
    [commit](https://github.com/rails/rails/commit/e93f0f0f133717f9b06b1eaefd3442bd0ff43985))

*   Added wildcard matching to explicit dependencies.
    ([Pull Request](https://github.com/rails/rails/pull/20904))

*   Make `disable_with` the default behavior for submit tags. Disables the
    button on submit to prevent double submits.
    ([Pull Request](https://github.com/rails/rails/pull/21135))

*   Partial template name no longer has to be a valid Ruby identifier.
    ([commit](https://github.com/rails/rails/commit/da9038e))

*   The `datetime_tag` helper now generates an input tag with the type of
    `datetime-local`.
    ([Pull Request](https://github.com/rails/rails/pull/25469))

*   Allow blocks while rendering with the `render partial:` helper.
    ([Pull Request](https://github.com/rails/rails/pull/17974))

Action Mailer
-------------

Please refer to the [Changelog][action-mailer] for detailed changes.

### Removals

*   Removed deprecated `*_path` helpers in email views.
    ([commit](https://github.com/rails/rails/commit/d282125a18c1697a9b5bb775628a2db239142ac7))

*   Removed deprecated `deliver` and `deliver!` methods.
    ([commit](https://github.com/rails/rails/commit/755dcd0691f74079c24196135f89b917062b0715))

### Notable changes

*   Template lookup now respects default locale and I18n fallbacks.
    ([commit](https://github.com/rails/rails/commit/ecb1981b))

*   Added `_mailer` suffix to mailers created via generator, following the same
    naming convention used in controllers and jobs.
    ([Pull Request](https://github.com/rails/rails/pull/18074))

*   Added `assert_enqueued_emails` and `assert_no_enqueued_emails`.
    ([Pull Request](https://github.com/rails/rails/pull/18403))

*   Added `config.action_mailer.deliver_later_queue_name` configuration to set
    the mailer queue name.
    ([Pull Request](https://github.com/rails/rails/pull/18587))

*   Added support for fragment caching in Action Mailer views.
    Added new config option `config.action_mailer.perform_caching` to determine
    whether your templates should perform caching or not.
    ([Pull Request](https://github.com/rails/rails/pull/22825))


Active Record
-------------

Please refer to the [Changelog][active-record] for detailed changes.

### Removals

*   Removed deprecated behavior allowing nested arrays to be passed as query
    values. ([Pull Request](https://github.com/rails/rails/pull/17919))

*   Removed deprecated `ActiveRecord::Tasks::DatabaseTasks#load_schema`. This
    method was replaced by `ActiveRecord::Tasks::DatabaseTasks#load_schema_for`.
    ([commit](https://github.com/rails/rails/commit/ad783136d747f73329350b9bb5a5e17c8f8800da))

*   Removed deprecated `serialized_attributes`.
    ([commit](https://github.com/rails/rails/commit/82043ab53cb186d59b1b3be06122861758f814b2))

*   Removed deprecated automatic counter caches on `has_many :through`.
    ([commit](https://github.com/rails/rails/commit/87c8ce340c6c83342df988df247e9035393ed7a0))

*   Removed deprecated `sanitize_sql_hash_for_conditions`.
    ([commit](https://github.com/rails/rails/commit/3a59dd212315ebb9bae8338b98af259ac00bbef3))

*   Removed deprecated `Reflection#source_macro`.
    ([commit](https://github.com/rails/rails/commit/ede8c199a85cfbb6457d5630ec1e285e5ec49313))

*   Removed deprecated `symbolized_base_class` and `symbolized_sti_name`.
    ([commit](https://github.com/rails/rails/commit/9013e28e52eba3a6ffcede26f85df48d264b8951))

*   Removed deprecated `ActiveRecord::Base.disable_implicit_join_references=`.
    ([commit](https://github.com/rails/rails/commit/0fbd1fc888ffb8cbe1191193bf86933110693dfc))

*   Removed deprecated access to connection specification using a string accessor.
    ([commit](https://github.com/rails/rails/commit/efdc20f36ccc37afbb2705eb9acca76dd8aabd4f))

*   Removed deprecated support to preload instance-dependent associations.
    ([commit](https://github.com/rails/rails/commit/4ed97979d14c5e92eb212b1a629da0a214084078))

*   Removed deprecated support for PostgreSQL ranges with exclusive lower bounds.
    ([commit](https://github.com/rails/rails/commit/a076256d63f64d194b8f634890527a5ed2651115))

*   Removed deprecation when modifying a relation with cached Arel.
    This raises an `ImmutableRelation` error instead.
    ([commit](https://github.com/rails/rails/commit/3ae98181433dda1b5e19910e107494762512a86c))

*   Removed `ActiveRecord::Serialization::XmlSerializer` from core. This feature
    has been extracted into the
    [activemodel-serializers-xml](https://github.com/rails/activemodel-serializers-xml)
    gem. ([Pull Request](https://github.com/rails/rails/pull/21161))

*   Removed support for the legacy `mysql` database adapter from core. Most users should
    be able to use `mysql2`. It will be converted to a separate gem when we find someone
    to maintain it. ([Pull Request 1](https://github.com/rails/rails/pull/22642),
    [Pull Request 2](https://github.com/rails/rails/pull/22715))

*   Removed support for the `protected_attributes` gem.
    ([commit](https://github.com/rails/rails/commit/f4fbc0301021f13ae05c8e941c8efc4ae351fdf9))

*   Removed support for PostgreSQL versions below 9.1.
    ([Pull Request](https://github.com/rails/rails/pull/23434))

*   Removed support for `activerecord-deprecated_finders` gem.
    ([commit](https://github.com/rails/rails/commit/78dab2a8569408658542e462a957ea5a35aa4679))

*   Removed `ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES` constant.
    ([commit](https://github.com/rails/rails/commit/a502703c3d2151d4d3b421b29fefdac5ad05df61))

### Deprecations

*   Deprecated passing a class as a value in a query. Users should pass strings
    instead. ([Pull Request](https://github.com/rails/rails/pull/17916))

*   Deprecated returning `false` as a way to halt Active Record callback
    chains. The recommended way is to
    `throw(:abort)`. ([Pull Request](https://github.com/rails/rails/pull/17227))

*   Deprecated `ActiveRecord::Base.errors_in_transactional_callbacks=`.
    ([commit](https://github.com/rails/rails/commit/07d3d402341e81ada0214f2cb2be1da69eadfe72))

*   Deprecated `Relation#uniq` use `Relation#distinct` instead.
    ([commit](https://github.com/rails/rails/commit/adfab2dcf4003ca564d78d4425566dd2d9cd8b4f))

*   Deprecated the PostgreSQL `:point` type in favor of a new one which will return
    `Point` objects instead of an `Array`
    ([Pull Request](https://github.com/rails/rails/pull/20448))

*   Deprecated force association reload by passing a truthy argument to
    association method.
    ([Pull Request](https://github.com/rails/rails/pull/20888))

*   Deprecated the keys for association `restrict_dependent_destroy` errors in favor
    of new key names.
    ([Pull Request](https://github.com/rails/rails/pull/20668))

*   Synchronize behavior of `#tables`.
    ([Pull Request](https://github.com/rails/rails/pull/21601))

*   Deprecated `SchemaCache#tables`, `SchemaCache#table_exists?` and
    `SchemaCache#clear_table_cache!` in favor of their new data source
    counterparts.
    ([Pull Request](https://github.com/rails/rails/pull/21715))

*   Deprecated `connection.tables` on the SQLite3 and MySQL adapters.
    ([Pull Request](https://github.com/rails/rails/pull/21601))

*   Deprecated passing arguments to `#tables` - the `#tables` method of some
    adapters (mysql2, sqlite3) would return both tables and views while others
    (postgresql) just return tables. To make their behavior consistent,
    `#tables` will return only tables in the future.
    ([Pull Request](https://github.com/rails/rails/pull/21601))

*   Deprecated `table_exists?` - The `#table_exists?` method would check both
    tables and views. To make their behavior consistent with `#tables`,
    `#table_exists?` will check only tables in the future.
    ([Pull Request](https://github.com/rails/rails/pull/21601))

*   Deprecate sending the `offset` argument to `find_nth`. Please use the
    `offset` method on relation instead.
    ([Pull Request](https://github.com/rails/rails/pull/22053))

*   Deprecated `{insert|update|delete}_sql` in `DatabaseStatements`.
    Use the `{insert|update|delete}` public methods instead.
    ([Pull Request](https://github.com/rails/rails/pull/23086))

*   Deprecated `use_transactional_fixtures` in favor of
    `use_transactional_tests` for more clarity.
    ([Pull Request](https://github.com/rails/rails/pull/19282))

*   Deprecated passing a column to `ActiveRecord::Connection#quote`.
    ([commit](https://github.com/rails/rails/commit/7bb620869725ad6de603f6a5393ee17df13aa96c))

*   Added an option `end` to `find_in_batches` that complements the `start`
    parameter to specify where to stop batch processing.
    ([Pull Request](https://github.com/rails/rails/pull/12257))


### Notable changes

*   Added a `foreign_key` option to `references` while creating the table.
    ([commit](https://github.com/rails/rails/commit/99a6f9e60ea55924b44f894a16f8de0162cf2702))

*   New attributes
    API. ([commit](https://github.com/rails/rails/commit/8c752c7ac739d5a86d4136ab1e9d0142c4041e58))

*   Added `:_prefix`/`:_suffix` option to `enum` definition.
    ([Pull Request](https://github.com/rails/rails/pull/19813),
     [Pull Request](https://github.com/rails/rails/pull/20999))

*   Added `#cache_key` to `ActiveRecord::Relation`.
    ([Pull Request](https://github.com/rails/rails/pull/20884))

*   Changed the default `null` value for `timestamps` to `false`.
    ([commit](https://github.com/rails/rails/commit/a939506f297b667291480f26fa32a373a18ae06a))

*   Added `ActiveRecord::SecureToken` in order to encapsulate generation of
    unique tokens for attributes in a model using `SecureRandom`.
    ([Pull Request](https://github.com/rails/rails/pull/18217))

*   Added `:if_exists` option for `drop_table`.
    ([Pull Request](https://github.com/rails/rails/pull/18597))

*   Added `ActiveRecord::Base#accessed_fields`, which can be used to quickly
    discover which fields were read from a model when you are looking to only
    select the data you need from the database.
    ([commit](https://github.com/rails/rails/commit/be9b68038e83a617eb38c26147659162e4ac3d2c))

*   Added the `#or` method on `ActiveRecord::Relation`, allowing use of the OR
    operator to combine WHERE or HAVING clauses.
    ([commit](https://github.com/rails/rails/commit/b0b37942d729b6bdcd2e3178eda7fa1de203b3d0))

*   Added `ActiveRecord::Base.suppress` to prevent the receiver from being saved
    during the given block.
    ([Pull Request](https://github.com/rails/rails/pull/18910))

*   `belongs_to` will now trigger a validation error by default if the
    association is not present. You can turn this off on a per-association basis
    with `optional: true`. Also deprecate `required` option in favor of `optional`
    for `belongs_to`.
    ([Pull Request](https://github.com/rails/rails/pull/18937))

*   Added `config.active_record.dump_schemas` to configure the behavior of
    `db:structure:dump`.
    ([Pull Request](https://github.com/rails/rails/pull/19347))

*   Added `config.active_record.warn_on_records_fetched_greater_than` option.
    ([Pull Request](https://github.com/rails/rails/pull/18846))

*   Added a native JSON data type support in MySQL.
    ([Pull Request](https://github.com/rails/rails/pull/21110))

*   Added support for dropping indexes concurrently in PostgreSQL.
    ([Pull Request](https://github.com/rails/rails/pull/21317))

*   Added `#views` and `#view_exists?` methods on connection adapters.
    ([Pull Request](https://github.com/rails/rails/pull/21609))

*   Added `ActiveRecord::Base.ignored_columns` to make some columns
    invisible from Active Record.
    ([Pull Request](https://github.com/rails/rails/pull/21720))

*   Added `connection.data_sources` and `connection.data_source_exists?`.
    These methods determine what relations can be used to back Active Record
    models (usually tables and views).
    ([Pull Request](https://github.com/rails/rails/pull/21715))

*   Allow fixtures files to set the model class in the YAML file itself.
    ([Pull Request](https://github.com/rails/rails/pull/20574))

*   Added ability to default to `uuid` as primary key when generating database
    migrations. ([Pull Request](https://github.com/rails/rails/pull/21762))

*   Added `ActiveRecord::Relation#left_joins` and
    `ActiveRecord::Relation#left_outer_joins`.
    ([Pull Request](https://github.com/rails/rails/pull/12071))

*   Added `after_{create,update,delete}_commit` callbacks.
    ([Pull Request](https://github.com/rails/rails/pull/22516))

*   Version the API presented to migration classes, so we can change parameter
    defaults without breaking existing migrations, or forcing them to be
    rewritten through a deprecation cycle.
    ([Pull Request](https://github.com/rails/rails/pull/21538))

*   `ApplicationRecord` is a new superclass for all app models, analogous to app
    controllers subclassing `ApplicationController` instead of
    `ActionController::Base`. This gives apps a single spot to configure app-wide
    model behavior.
    ([Pull Request](https://github.com/rails/rails/pull/22567))

*   Added ActiveRecord `#second_to_last` and `#third_to_last` methods.
    ([Pull Request](https://github.com/rails/rails/pull/23583))

*   Added ability to annotate database objects (tables, columns, indexes)
    with comments stored in database metadata for PostgreSQL & MySQL.
    ([Pull Request](https://github.com/rails/rails/pull/22911))

*   Added prepared statements support to `mysql2` adapter, for mysql2 0.4.4+,
    Previously this was only supported on the deprecated `mysql` legacy adapter.
    To enable, set `prepared_statements: true` in `config/database.yml`.
    ([Pull Request](https://github.com/rails/rails/pull/23461))

*   Added ability to call `ActionRecord::Relation#update` on relation objects
    which will run validations on callbacks on all objects in the relation.
    ([Pull Request](https://github.com/rails/rails/pull/11898))

*   Added `:touch` option to the `save` method so that records can be saved without
    updating timestamps.
    ([Pull Request](https://github.com/rails/rails/pull/18225))

*   Added expression indexes and operator classes support for PostgreSQL.
    ([commit](https://github.com/rails/rails/commit/edc2b7718725016e988089b5fb6d6fb9d6e16882))

*   Added `:index_errors` option to add indexes to errors of nested attributes.
    ([Pull Request](https://github.com/rails/rails/pull/19686))

*   Added support for bidirectional destroy dependencies.
    ([Pull Request](https://github.com/rails/rails/pull/18548))

*   Added support for `after_commit` callbacks in transactional tests.
    ([Pull Request](https://github.com/rails/rails/pull/18458))

*   Added `foreign_key_exists?` method to see if a foreign key exists on a table
    or not.
    ([Pull Request](https://github.com/rails/rails/pull/18662))

*   Added `:time` option to `touch` method to touch records with different time
    than the current time.
    ([Pull Request](https://github.com/rails/rails/pull/18956))

*   Change transaction callbacks to not swallow errors.
    Before this change any errors raised inside a transaction callback
    were getting rescued and printed in the logs, unless you used
    the (newly deprecated) `raise_in_transactional_callbacks = true` option.

    Now these errors are not rescued anymore and just bubble up, matching the
    behavior of other callbacks.
    ([commit](https://github.com/rails/rails/commit/07d3d402341e81ada0214f2cb2be1da69eadfe72))

Active Model
------------

Please refer to the [Changelog][active-model] for detailed changes.

### Removals

*   Removed deprecated `ActiveModel::Dirty#reset_#{attribute}` and
    `ActiveModel::Dirty#reset_changes`.
    ([Pull Request](https://github.com/rails/rails/commit/37175a24bd508e2983247ec5d011d57df836c743))

*   Removed XML serialization. This feature has been extracted into the
    [activemodel-serializers-xml](https://github.com/rails/activemodel-serializers-xml) gem.
    ([Pull Request](https://github.com/rails/rails/pull/21161))

*   Removed `ActionController::ModelNaming` module.
    ([Pull Request](https://github.com/rails/rails/pull/18194))

### Deprecations

*   Deprecated returning `false` as a way to halt Active Model and
    `ActiveModel::Validations` callback chains. The recommended way is to
    `throw(:abort)`. ([Pull Request](https://github.com/rails/rails/pull/17227))

*   Deprecated `ActiveModel::Errors#get`, `ActiveModel::Errors#set` and
    `ActiveModel::Errors#[]=` methods that have inconsistent behavior.
    ([Pull Request](https://github.com/rails/rails/pull/18634))

*   Deprecated the `:tokenizer` option for `validates_length_of`, in favor of
    plain Ruby.
    ([Pull Request](https://github.com/rails/rails/pull/19585))

*   Deprecated `ActiveModel::Errors#add_on_empty` and `ActiveModel::Errors#add_on_blank`
    with no replacement.
    ([Pull Request](https://github.com/rails/rails/pull/18996))

### Notable changes

*   Added `ActiveModel::Errors#details` to determine what validator has failed.
    ([Pull Request](https://github.com/rails/rails/pull/18322))

*   Extracted `ActiveRecord::AttributeAssignment` to `ActiveModel::AttributeAssignment`
    allowing to use it for any object as an includable module.
    ([Pull Request](https://github.com/rails/rails/pull/10776))

*   Added `ActiveModel::Dirty#[attr_name]_previously_changed?` and
    `ActiveModel::Dirty#[attr_name]_previous_change` to improve access
    to recorded changes after the model has been saved.
    ([Pull Request](https://github.com/rails/rails/pull/19847))

*   Validate multiple contexts on `valid?` and `invalid?` at once.
    ([Pull Request](https://github.com/rails/rails/pull/21069))

*   Change `validates_acceptance_of` to accept `true` as default value
    apart from `1`.
    ([Pull Request](https://github.com/rails/rails/pull/18439))

Active Job
-----------

Please refer to the [Changelog][active-job] for detailed changes.

### Notable changes

*   `ActiveJob::Base.deserialize` delegates to the job class. This allows jobs
    to attach arbitrary metadata when they get serialized and read it back when
    they get performed.
    ([Pull Request](https://github.com/rails/rails/pull/18260))

*   Add ability to configure the queue adapter on a per job basis without
    affecting each other.
    ([Pull Request](https://github.com/rails/rails/pull/16992))

*   A generated job now inherits from `app/jobs/application_job.rb` by default.
    ([Pull Request](https://github.com/rails/rails/pull/19034))

*   Allow `DelayedJob`, `Sidekiq`, `qu`, `que`, and `queue_classic` to report
    the job id back to `ActiveJob::Base` as `provider_job_id`.
    ([Pull Request](https://github.com/rails/rails/pull/20064),
     [Pull Request](https://github.com/rails/rails/pull/20056),
     [commit](https://github.com/rails/rails/commit/68e3279163d06e6b04e043f91c9470e9259bbbe0))

*   Implement a simple `AsyncJob` processor and associated `AsyncAdapter` that
    queue jobs to a `concurrent-ruby` thread pool.
    ([Pull Request](https://github.com/rails/rails/pull/21257))

*   Change the default adapter from inline to async. It's a better default as
    tests will then not mistakenly come to rely on behavior happening
    synchronously.
    ([commit](https://github.com/rails/rails/commit/625baa69d14881ac49ba2e5c7d9cac4b222d7022))

Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

### Removals

*   Removed deprecated `ActiveSupport::JSON::Encoding::CircularReferenceError`.
    ([commit](https://github.com/rails/rails/commit/d6e06ea8275cdc3f126f926ed9b5349fde374b10))

*   Removed deprecated methods `ActiveSupport::JSON::Encoding.encode_big_decimal_as_string=`
    and `ActiveSupport::JSON::Encoding.encode_big_decimal_as_string`.
    ([commit](https://github.com/rails/rails/commit/c8019c0611791b2716c6bed48ef8dcb177b7869c))

*   Removed deprecated `ActiveSupport::SafeBuffer#prepend`.
    ([commit](https://github.com/rails/rails/commit/e1c8b9f688c56aaedac9466a4343df955b4a67ec))

*   Removed deprecated methods from `Kernel`. `silence_stderr`, `silence_stream`,
    `capture` and `quietly`.
    ([commit](https://github.com/rails/rails/commit/481e49c64f790e46f4aff3ed539ed227d2eb46cb))

*   Removed deprecated `active_support/core_ext/big_decimal/yaml_conversions`
    file.
    ([commit](https://github.com/rails/rails/commit/98ea19925d6db642731741c3b91bd085fac92241))

*   Removed deprecated methods `ActiveSupport::Cache::Store.instrument` and
    `ActiveSupport::Cache::Store.instrument=`.
    ([commit](https://github.com/rails/rails/commit/a3ce6ca30ed0e77496c63781af596b149687b6d7))

*   Removed deprecated `Class#superclass_delegating_accessor`.
    Use `Class#class_attribute` instead.
    ([Pull Request](https://github.com/rails/rails/pull/16938))

*   Removed deprecated `ThreadSafe::Cache`. Use `Concurrent::Map` instead.
    ([Pull Request](https://github.com/rails/rails/pull/21679))

*   Removed `Object#itself` as it is implemented in Ruby 2.2.
    ([Pull Request](https://github.com/rails/rails/pull/18244))

### Deprecations

*   Deprecated `MissingSourceFile` in favor of `LoadError`.
    ([commit](https://github.com/rails/rails/commit/734d97d2))

*   Deprecated `alias_method_chain` in favour of `Module#prepend` introduced in
    Ruby 2.0.
    ([Pull Request](https://github.com/rails/rails/pull/19434))

*   Deprecated `ActiveSupport::Concurrency::Latch` in favor of
    `Concurrent::CountDownLatch` from concurrent-ruby.
    ([Pull Request](https://github.com/rails/rails/pull/20866))

*   Deprecated `:prefix` option of `number_to_human_size` with no replacement.
    ([Pull Request](https://github.com/rails/rails/pull/21191))

*   Deprecated `Module#qualified_const_` in favour of the builtin
    `Module#const_` methods.
    ([Pull Request](https://github.com/rails/rails/pull/17845))

*   Deprecated passing string to define callback.
    ([Pull Request](https://github.com/rails/rails/pull/22598))

*   Deprecated `ActiveSupport::Cache::Store#namespaced_key`,
    `ActiveSupport::Cache::MemCachedStore#escape_key`, and
    `ActiveSupport::Cache::FileStore#key_file_path`.
    Use `normalize_key` instead.
    ([Pull Request](https://github.com/rails/rails/pull/22215),
     [commit](https://github.com/rails/rails/commit/a8f773b0))

*   Deprecated `ActiveSupport::Cache::LocaleCache#set_cache_value` in favor of `write_cache_value`.
    ([Pull Request](https://github.com/rails/rails/pull/22215))

*   Deprecated passing arguments to `assert_nothing_raised`.
    ([Pull Request](https://github.com/rails/rails/pull/23789))

*   Deprecated `Module.local_constants` in favor of `Module.constants(false)`.
    ([Pull Request](https://github.com/rails/rails/pull/23936))


### Notable changes

*   Added `#verified` and `#valid_message?` methods to
    `ActiveSupport::MessageVerifier`.
    ([Pull Request](https://github.com/rails/rails/pull/17727))

*   Changed the way in which callback chains can be halted. The preferred method
    to halt a callback chain from now on is to explicitly `throw(:abort)`.
    ([Pull Request](https://github.com/rails/rails/pull/17227))

*   New config option
    `config.active_support.halt_callback_chains_on_return_false` to specify
    whether ActiveRecord, ActiveModel, and ActiveModel::Validations callback
    chains can be halted by returning `false` in a 'before' callback.
    ([Pull Request](https://github.com/rails/rails/pull/17227))

*   Changed the default test order from `:sorted` to `:random`.
    ([commit](https://github.com/rails/rails/commit/5f777e4b5ee2e3e8e6fd0e2a208ec2a4d25a960d))

*   Added `#on_weekend?`, `#on_weekday?`, `#next_weekday`, `#prev_weekday` methods to `Date`,
    `Time`, and `DateTime`.
    ([Pull Request](https://github.com/rails/rails/pull/18335),
     [Pull Request](https://github.com/rails/rails/pull/23687))

*   Added `same_time` option to `#next_week` and `#prev_week` for `Date`, `Time`,
    and `DateTime`.
    ([Pull Request](https://github.com/rails/rails/pull/18335))

*   Added `#prev_day` and `#next_day` counterparts to `#yesterday` and
    `#tomorrow` for `Date`, `Time`, and `DateTime`.
    ([Pull Request](https://github.com/rails/rails/pull/18335))

*   Added `SecureRandom.base58` for generation of random base58 strings.
    ([commit](https://github.com/rails/rails/commit/b1093977110f18ae0cafe56c3d99fc22a7d54d1b))

*   Added `file_fixture` to `ActiveSupport::TestCase`.
    It provides a simple mechanism to access sample files in your test cases.
    ([Pull Request](https://github.com/rails/rails/pull/18658))

*   Added `#without` on `Enumerable` and `Array` to return a copy of an
    enumerable without the specified elements.
    ([Pull Request](https://github.com/rails/rails/pull/19157))

*   Added `ActiveSupport::ArrayInquirer` and `Array#inquiry`.
    ([Pull Request](https://github.com/rails/rails/pull/18939))

*   Added `ActiveSupport::TimeZone#strptime` to allow parsing times as if
    from a given timezone.
    ([commit](https://github.com/rails/rails/commit/a5e507fa0b8180c3d97458a9b86c195e9857d8f6))

*   Added `Integer#positive?` and `Integer#negative?` query methods
    in the vein of `Integer#zero?`.
    ([commit](https://github.com/rails/rails/commit/e54277a45da3c86fecdfa930663d7692fd083daa))

*   Added a bang version to `ActiveSupport::OrderedOptions` get methods which will raise
    an `KeyError` if the value is `.blank?`.
    ([Pull Request](https://github.com/rails/rails/pull/20208))

*   Added `Time.days_in_year` to return the number of days in the given year, or the
    current year if no argument is provided.
    ([commit](https://github.com/rails/rails/commit/2f4f4d2cf1e4c5a442459fc250daf66186d110fa))

*   Added an evented file watcher to asynchronously detect changes in the
    application source code, routes, locales, etc.
    ([Pull Request](https://github.com/rails/rails/pull/22254))

*   Added thread_m/cattr_accessor/reader/writer suite of methods for declaring
    class and module variables that live per-thread.
    ([Pull Request](https://github.com/rails/rails/pull/22630))

*   Added `Array#second_to_last` and `Array#third_to_last` methods.
    ([Pull Request](https://github.com/rails/rails/pull/23583))

*   Publish `ActiveSupport::Executor` and `ActiveSupport::Reloader` APIs to allow
    components and libraries to manage, and participate in, the execution of
    application code, and the application reloading process.
    ([Pull Request](https://github.com/rails/rails/pull/23807))

*   `ActiveSupport::Duration` now supports ISO8601 formatting and parsing.
    ([Pull Request](https://github.com/rails/rails/pull/16917))

*   `ActiveSupport::JSON.decode` now supports parsing ISO8601 local times when
    `parse_json_times` is enabled.
    ([Pull Request](https://github.com/rails/rails/pull/23011))

*   `ActiveSupport::JSON.decode` now return `Date` objects for date strings.
    ([Pull Request](https://github.com/rails/rails/pull/23011))

*   Added ability to `TaggedLogging` to allow loggers to be instantiated multiple
    times so that they don't share tags with each other.
    ([Pull Request](https://github.com/rails/rails/pull/9065))

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
[action-cable]:   https://github.com/rails/rails/blob/5-0-stable/actioncable/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/5-0-stable/activerecord/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/5-0-stable/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/5-0-stable/activesupport/CHANGELOG.md
[active-job]:     https://github.com/rails/rails/blob/5-0-stable/activejob/CHANGELOG.md
