**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Ruby on Rails 4.1 Release Notes
===============================

Highlights in Rails 4.1:

* Spring application preloader
* `config/secrets.yml`
* Action Pack variants
* Action Mailer previews

These release notes cover only the major changes. To learn about various bug
fixes and changes, please refer to the change logs or check out the [list of
commits](https://github.com/rails/rails/commits/4-1-stable) in the main Rails
repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 4.1
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 4.0 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 4.1. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-4-0-to-rails-4-1)
guide.


Major Features
--------------

### Spring Application Preloader

Spring is a Rails application preloader. It speeds up development by keeping
your application running in the background so you don't need to boot it every
time you run a test, rake task or migration.

New Rails 4.1 applications will ship with "springified" binstubs. This means
that `bin/rails` and `bin/rake` will automatically take advantage of preloaded
spring environments.

**Running rake tasks:**

```
bin/rake test:models
```

**Running a Rails command:**

```
bin/rails console
```

**Spring introspection:**

```
$ bin/spring status
Spring is running:

 1182 spring server | my_app | started 29 mins ago
 3656 spring app    | my_app | started 23 secs ago | test mode
 3746 spring app    | my_app | started 10 secs ago | development mode
```

Have a look at the
[Spring README](https://github.com/rails/spring/blob/master/README.md) to
see all available features.

See the [Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#spring)
guide on how to migrate existing applications to use this feature.

### `config/secrets.yml`

Rails 4.1 generates a new `secrets.yml` file in the `config` folder. By default,
this file contains the application's `secret_key_base`, but it could also be
used to store other secrets such as access keys for external APIs.

The secrets added to this file are accessible via `Rails.application.secrets`.
For example, with the following `config/secrets.yml`:

```yaml
development:
  secret_key_base: 3b7cd727ee24e8444053437c36cc66c3
  some_api_key: SOMEKEY
```

`Rails.application.secrets.some_api_key` returns `SOMEKEY` in the development
environment.

See the [Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#config-secrets-yml)
guide on how to migrate existing applications to use this feature.

### Action Pack Variants

We often want to render different HTML/JSON/XML templates for phones,
tablets, and desktop browsers. Variants make it easy.

The request variant is a specialization of the request format, like `:tablet`,
`:phone`, or `:desktop`.

You can set the variant in a `before_action`:

```ruby
request.variant = :tablet if request.user_agent =~ /iPad/
```

Respond to variants in the action just like you respond to formats:

```ruby
respond_to do |format|
  format.html do |html|
    html.tablet # renders app/views/projects/show.html+tablet.erb
    html.phone { extra_setup; render ... }
  end
end
```

Provide separate templates for each format and variant:

```
app/views/projects/show.html.erb
app/views/projects/show.html+tablet.erb
app/views/projects/show.html+phone.erb
```

You can also simplify the variants definition using the inline syntax:

```ruby
respond_to do |format|
  format.js         { render "trash" }
  format.html.phone { redirect_to progress_path }
  format.html.none  { render "trash" }
end
```

### Action Mailer Previews

Action Mailer previews provide a way to see how emails look by visiting
a special URL that renders them.

You implement a preview class whose methods return the mail object you'd like
to check:

```ruby
class NotifierPreview < ActionMailer::Preview
  def welcome
    Notifier.welcome(User.first)
  end
end
```

The preview is available in http://localhost:3000/rails/mailers/notifier/welcome,
and a list of them in http://localhost:3000/rails/mailers.

By default, these preview classes live in `test/mailers/previews`.
This can be configured using the `preview_path` option.

See its
[documentation](https://api.rubyonrails.org/v4.1.0/classes/ActionMailer/Base.html#class-ActionMailer::Base-label-Previewing+emails)
for a detailed write up.

### Active Record enums

Declare an enum attribute where the values map to integers in the database, but
can be queried by name.

```ruby
class Conversation < ActiveRecord::Base
  enum status: [ :active, :archived ]
end

conversation.archived!
conversation.active? # => false
conversation.status  # => "archived"

Conversation.archived # => Relation for all archived Conversations

Conversation.statuses # => { "active" => 0, "archived" => 1 }
```

See its
[documentation](http://api.rubyonrails.org/v4.1.0/classes/ActiveRecord/Enum.html)
for a detailed write up.

### Message Verifiers

Message verifiers can be used to generate and verify signed messages. This can
be useful to safely transport sensitive data like remember-me tokens and
friends.

The method `Rails.application.message_verifier` returns a new message verifier
that signs messages with a key derived from secret_key_base and the given
message verifier name:

```ruby
signed_token = Rails.application.message_verifier(:remember_me).generate(token)
Rails.application.message_verifier(:remember_me).verify(signed_token) # => token

Rails.application.message_verifier(:remember_me).verify(tampered_token)
# raises ActiveSupport::MessageVerifier::InvalidSignature
```

### Module#concerning

A natural, low-ceremony way to separate responsibilities within a class:

```ruby
class Todo < ActiveRecord::Base
  concerning :EventTracking do
    included do
      has_many :events
    end

    def latest_event
      ...
    end

    private
      def some_internal_method
        ...
      end
  end
end
```

This example is equivalent to defining a `EventTracking` module inline,
extending it with `ActiveSupport::Concern`, then mixing it in to the
`Todo` class.

See its
[documentation](https://api.rubyonrails.org/v4.1.0/classes/Module/Concerning.html)
for a detailed write up and the intended use cases.

### CSRF protection from remote `<script>` tags

Cross-site request forgery (CSRF) protection now covers GET requests with
JavaScript responses, too. That prevents a third-party site from referencing
your JavaScript URL and attempting to run it to extract sensitive data.

This means any of your tests that hit `.js` URLs will now fail CSRF protection
unless they use `xhr`. Upgrade your tests to be explicit about expecting
XmlHttpRequests. Instead of `post :create, format: :js`, switch to the explicit
`xhr :post, :create, format: :js`.


Railties
--------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/railties/CHANGELOG.md)
for detailed changes.

### Removals

* Removed `update:application_controller` rake task.

* Removed deprecated `Rails.application.railties.engines`.

* Removed deprecated `threadsafe!` from Rails Config.

* Removed deprecated `ActiveRecord::Generators::ActiveModel#update_attributes` in
  favor of `ActiveRecord::Generators::ActiveModel#update`.

* Removed deprecated `config.whiny_nils` option.

* Removed deprecated rake tasks for running tests: `rake test:uncommitted` and
  `rake test:recent`.

### Notable changes

* The [Spring application
  preloader](https://github.com/rails/spring) is now installed
  by default for new applications. It uses the development group of
  the `Gemfile`, so will not be installed in
  production. ([Pull Request](https://github.com/rails/rails/pull/12958))

* `BACKTRACE` environment variable to show unfiltered backtraces for test
  failures. ([Commit](https://github.com/rails/rails/commit/84eac5dab8b0fe9ee20b51250e52ad7bfea36553))

* Exposed `MiddlewareStack#unshift` to environment
  configuration. ([Pull Request](https://github.com/rails/rails/pull/12479))

* Added `Application#message_verifier` method to return a message
  verifier. ([Pull Request](https://github.com/rails/rails/pull/12995))

* The `test_help.rb` file which is required by the default generated test
  helper will automatically keep your test database up-to-date with
  `db/schema.rb` (or `db/structure.sql`). It raises an error if
  reloading the schema does not resolve all pending migrations. Opt out
  with `config.active_record.maintain_test_schema = false`. ([Pull
  Request](https://github.com/rails/rails/pull/13528))

* Introduce `Rails.gem_version` as a convenience method to return
  `Gem::Version.new(Rails.version)`, suggesting a more reliable way to perform
  version comparison. ([Pull Request](https://github.com/rails/rails/pull/14103))


Action Pack
-----------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/actionpack/CHANGELOG.md)
for detailed changes.

### Removals

* Removed deprecated Rails application fallback for integration testing, set
  `ActionDispatch.test_app` instead.

* Removed deprecated `page_cache_extension` config.

* Removed deprecated `ActionController::RecordIdentifier`, use
  `ActionView::RecordIdentifier` instead.

* Removed deprecated constants from Action Controller:

| Removed                            | Successor                       |
|:-----------------------------------|:--------------------------------|
| ActionController::AbstractRequest  | ActionDispatch::Request         |
| ActionController::Request          | ActionDispatch::Request         |
| ActionController::AbstractResponse | ActionDispatch::Response        |
| ActionController::Response         | ActionDispatch::Response        |
| ActionController::Routing          | ActionDispatch::Routing         |
| ActionController::Integration      | ActionDispatch::Integration     |
| ActionController::IntegrationTest  | ActionDispatch::IntegrationTest |

### Notable changes

* `protect_from_forgery` also prevents cross-origin `<script>` tags.
  Update your tests to use `xhr :get, :foo, format: :js` instead of
  `get :foo, format: :js`.
  ([Pull Request](https://github.com/rails/rails/pull/13345))

* `#url_for` takes a hash with options inside an
  array. ([Pull Request](https://github.com/rails/rails/pull/9599))

* Added `session#fetch` method fetch behaves similarly to
  [Hash#fetch](http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-fetch),
  with the exception that the returned value is always saved into the
  session. ([Pull Request](https://github.com/rails/rails/pull/12692))

* Separated Action View completely from Action
  Pack. ([Pull Request](https://github.com/rails/rails/pull/11032))

* Log which keys were affected by deep
  munge. ([Pull Request](https://github.com/rails/rails/pull/13813))

* New config option `config.action_dispatch.perform_deep_munge` to opt out of
  params "deep munging" that was used to address security vulnerability
  CVE-2013-0155. ([Pull Request](https://github.com/rails/rails/pull/13188))

* New config option `config.action_dispatch.cookies_serializer` for specifying a
  serializer for the signed and encrypted cookie jars. (Pull Requests
  [1](https://github.com/rails/rails/pull/13692),
  [2](https://github.com/rails/rails/pull/13945) /
  [More Details](upgrading_ruby_on_rails.html#cookies-serializer))

* Added `render :plain`, `render :html` and `render
  :body`. ([Pull Request](https://github.com/rails/rails/pull/14062) /
  [More Details](upgrading_ruby_on_rails.html#rendering-content-from-string))


Action Mailer
-------------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/actionmailer/CHANGELOG.md)
for detailed changes.

### Notable changes

* Added mailer previews feature based on 37 Signals mail_view
  gem. ([Commit](https://github.com/rails/rails/commit/d6dec7fcb6b8fddf8c170182d4fe64ecfc7b2261))

* Instrument the generation of Action Mailer messages. The time it takes to
  generate a message is written to the log. ([Pull Request](https://github.com/rails/rails/pull/12556))


Active Record
-------------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/activerecord/CHANGELOG.md)
for detailed changes.

### Removals

* Removed deprecated nil-passing to the following `SchemaCache` methods:
  `primary_keys`, `tables`, `columns` and `columns_hash`.

* Removed deprecated block filter from `ActiveRecord::Migrator#migrate`.

* Removed deprecated String constructor from `ActiveRecord::Migrator`.

* Removed deprecated `scope` use without passing a callable object.

* Removed deprecated `transaction_joinable=` in favor of `begin_transaction`
  with a `:joinable` option.

* Removed deprecated `decrement_open_transactions`.

* Removed deprecated `increment_open_transactions`.

* Removed deprecated `PostgreSQLAdapter#outside_transaction?`
  method. You can use `#transaction_open?` instead.

* Removed deprecated `ActiveRecord::Fixtures.find_table_name` in favor of
  `ActiveRecord::Fixtures.default_fixture_model_name`.

* Removed deprecated `columns_for_remove` from `SchemaStatements`.

* Removed deprecated `SchemaStatements#distinct`.

* Moved deprecated `ActiveRecord::TestCase` into the Rails test
  suite. The class is no longer public and is only used for internal
  Rails tests.

* Removed support for deprecated option `:restrict` for `:dependent`
  in associations.

* Removed support for deprecated `:delete_sql`, `:insert_sql`, `:finder_sql`
  and `:counter_sql` options in associations.

* Removed deprecated method `type_cast_code` from Column.

* Removed deprecated `ActiveRecord::Base#connection` method.
  Make sure to access it via the class.

* Removed deprecation warning for `auto_explain_threshold_in_seconds`.

* Removed deprecated `:distinct` option from `Relation#count`.

* Removed deprecated methods `partial_updates`, `partial_updates?` and
  `partial_updates=`.

* Removed deprecated method `scoped`.

* Removed deprecated method `default_scopes?`.

* Remove implicit join references that were deprecated in 4.0.

* Removed `activerecord-deprecated_finders` as a dependency.
  Please see [the gem README](https://github.com/rails/activerecord-deprecated_finders#active-record-deprecated-finders)
  for more info.

* Removed usage of `implicit_readonly`. Please use `readonly` method
  explicitly to mark records as
  `readonly`. ([Pull Request](https://github.com/rails/rails/pull/10769))

### Deprecations

* Deprecated `quoted_locking_column` method, which isn't used anywhere.

* Deprecated `ConnectionAdapters::SchemaStatements#distinct`,
  as it is no longer used by internals. ([Pull Request](https://github.com/rails/rails/pull/10556))

* Deprecated `rake db:test:*` tasks as the test database is now
  automatically maintained. See railties release notes. ([Pull
  Request](https://github.com/rails/rails/pull/13528))

* Deprecate unused `ActiveRecord::Base.symbolized_base_class`
  and `ActiveRecord::Base.symbolized_sti_name` without
  replacement. [Commit](https://github.com/rails/rails/commit/97e7ca48c139ea5cce2fa9b4be631946252a1ebd)

### Notable changes

* Default scopes are no longer overridden by chained conditions.

  Before this change when you defined a `default_scope` in a model
  it was overridden by chained conditions in the same field. Now it
  is merged like any other scope. [More Details](upgrading_ruby_on_rails.html#changes-on-default-scopes).

* Added `ActiveRecord::Base.to_param` for convenient "pretty" URLs derived from
  a model's attribute or
  method. ([Pull Request](https://github.com/rails/rails/pull/12891))

* Added `ActiveRecord::Base.no_touching`, which allows ignoring touch on
  models. ([Pull Request](https://github.com/rails/rails/pull/12772))

* Unify boolean type casting for `MysqlAdapter` and `Mysql2Adapter`.
  `type_cast` will return `1` for `true` and `0` for `false`. ([Pull Request](https://github.com/rails/rails/pull/12425))

* `.unscope` now removes conditions specified in
  `default_scope`. ([Commit](https://github.com/rails/rails/commit/94924dc32baf78f13e289172534c2e71c9c8cade))

* Added `ActiveRecord::QueryMethods#rewhere` which will overwrite an existing,
  named where condition. ([Commit](https://github.com/rails/rails/commit/f950b2699f97749ef706c6939a84dfc85f0b05f2))

* Extended `ActiveRecord::Base#cache_key` to take an optional list of timestamp
  attributes of which the highest will be used. ([Commit](https://github.com/rails/rails/commit/e94e97ca796c0759d8fcb8f946a3bbc60252d329))

* Added `ActiveRecord::Base#enum` for declaring enum attributes where the values
  map to integers in the database, but can be queried by
  name. ([Commit](https://github.com/rails/rails/commit/db41eb8a6ea88b854bf5cd11070ea4245e1639c5))

* Type cast json values on write, so that the value is consistent with reading
  from the database. ([Pull Request](https://github.com/rails/rails/pull/12643))

* Type cast hstore values on write, so that the value is consistent
  with reading from the database. ([Commit](https://github.com/rails/rails/commit/5ac2341fab689344991b2a4817bd2bc8b3edac9d))

* Make `next_migration_number` accessible for third party
  generators. ([Pull Request](https://github.com/rails/rails/pull/12407))

* Calling `update_attributes` will now throw an `ArgumentError` whenever it
  gets a `nil` argument. More specifically, it will throw an error if the
  argument that it gets passed does not respond to to
  `stringify_keys`. ([Pull Request](https://github.com/rails/rails/pull/9860))

* `CollectionAssociation#first`/`#last` (e.g. `has_many`) use a `LIMIT`ed
  query to fetch results rather than loading the entire
  collection. ([Pull Request](https://github.com/rails/rails/pull/12137))

* `inspect` on Active Record model classes does not initiate a new
  connection. This means that calling `inspect`, when the database is missing,
  will no longer raise an exception. ([Pull Request](https://github.com/rails/rails/pull/11014))

* Removed column restrictions for `count`, let the database raise if the SQL is
  invalid. ([Pull Request](https://github.com/rails/rails/pull/10710))

* Rails now automatically detects inverse associations. If you do not set the
  `:inverse_of` option on the association, then Active Record will guess the
  inverse association based on heuristics. ([Pull Request](https://github.com/rails/rails/pull/10886))

* Handle aliased attributes in ActiveRecord::Relation. When using symbol keys,
  ActiveRecord will now translate aliased attribute names to the actual column
  name used in the database. ([Pull Request](https://github.com/rails/rails/pull/7839))

* The ERB in fixture files is no longer evaluated in the context of the main
  object. Helper methods used by multiple fixtures should be defined on modules
  included in `ActiveRecord::FixtureSet.context_class`. ([Pull Request](https://github.com/rails/rails/pull/13022))

* Don't create or drop the test database if RAILS_ENV is specified
  explicitly. ([Pull Request](https://github.com/rails/rails/pull/13629))

* `Relation` no longer has mutator methods like `#map!` and `#delete_if`. Convert
  to an `Array` by calling `#to_a` before using these methods. ([Pull Request](https://github.com/rails/rails/pull/13314))

* `find_in_batches`, `find_each`, `Result#each` and `Enumerable#index_by` now
  return an `Enumerator` that can calculate its
  size. ([Pull Request](https://github.com/rails/rails/pull/13938))

* `scope`, `enum` and Associations now raise on "dangerous" name
  conflicts. ([Pull Request](https://github.com/rails/rails/pull/13450),
  [Pull Request](https://github.com/rails/rails/pull/13896))

* `second` through `fifth` methods act like the `first`
  finder. ([Pull Request](https://github.com/rails/rails/pull/13757))

* Make `touch` fire the `after_commit` and `after_rollback`
  callbacks. ([Pull Request](https://github.com/rails/rails/pull/12031))

* Enable partial indexes for `sqlite >= 3.8.0`.
  ([Pull Request](https://github.com/rails/rails/pull/13350))

* Make `change_column_null`
  revertible. ([Commit](https://github.com/rails/rails/commit/724509a9d5322ff502aefa90dd282ba33a281a96))

* Added a flag to disable schema dump after migration. This is set to `false`
  by default in the production environment for new applications.
  ([Pull Request](https://github.com/rails/rails/pull/13948))

Active Model
------------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/activemodel/CHANGELOG.md)
for detailed changes.

### Deprecations

* Deprecate `Validator#setup`. This should be done manually now in the
  validator's constructor. ([Commit](https://github.com/rails/rails/commit/7d84c3a2f7ede0e8d04540e9c0640de7378e9b3a))

### Notable changes

* Added new API methods `reset_changes` and `changes_applied` to
  `ActiveModel::Dirty` that control changes state.

* Ability to specify multiple contexts when defining a
  validation. ([Pull Request](https://github.com/rails/rails/pull/13754))

* `attribute_changed?` now accepts a hash to check if the attribute was changed
  `:from` and/or `:to` a given
  value. ([Pull Request](https://github.com/rails/rails/pull/13131))


Active Support
--------------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-1-stable/activesupport/CHANGELOG.md)
for detailed changes.


### Removals

* Removed `MultiJSON` dependency. As a result, `ActiveSupport::JSON.decode`
  no longer accepts an options hash for `MultiJSON`. ([Pull Request](https://github.com/rails/rails/pull/10576) / [More Details](upgrading_ruby_on_rails.html#changes-in-json-handling))

* Removed support for the `encode_json` hook used for encoding custom objects into
  JSON. This feature has been extracted into the [activesupport-json_encoder](https://github.com/rails/activesupport-json_encoder)
  gem.
  ([Related Pull Request](https://github.com/rails/rails/pull/12183) /
  [More Details](upgrading_ruby_on_rails.html#changes-in-json-handling))

* Removed deprecated `ActiveSupport::JSON::Variable` with no replacement.

* Removed deprecated `String#encoding_aware?` core extensions (`core_ext/string/encoding`).

* Removed deprecated `Module#local_constant_names` in favor of `Module#local_constants`.

* Removed deprecated `DateTime.local_offset` in favor of `DateTime.civil_from_format`.

* Removed deprecated `Logger` core extensions (`core_ext/logger.rb`).

* Removed deprecated `Time#time_with_datetime_fallback`, `Time#utc_time` and
  `Time#local_time` in favor of `Time#utc` and `Time#local`.

* Removed deprecated `Hash#diff` with no replacement.

* Removed deprecated `Date#to_time_in_current_zone` in favor of `Date#in_time_zone`.

* Removed deprecated `Proc#bind` with no replacement.

* Removed deprecated `Array#uniq_by` and `Array#uniq_by!`, use native
  `Array#uniq` and `Array#uniq!` instead.

* Removed deprecated `ActiveSupport::BasicObject`, use
  `ActiveSupport::ProxyObject` instead.

* Removed deprecated `BufferedLogger`, use `ActiveSupport::Logger` instead.

* Removed deprecated `assert_present` and `assert_blank` methods, use `assert
  object.blank?` and `assert object.present?` instead.

* Remove deprecated `#filter` method for filter objects, use the corresponding
  method instead (e.g. `#before` for a before filter).

* Removed 'cow' => 'kine' irregular inflection from default
  inflections. ([Commit](https://github.com/rails/rails/commit/c300dca9963bda78b8f358dbcb59cabcdc5e1dc9))

### Deprecations

* Deprecated `Numeric#{ago,until,since,from_now}`, the user is expected to
  explicitly convert the value into an AS::Duration, i.e. `5.ago` => `5.seconds.ago`
  ([Pull Request](https://github.com/rails/rails/pull/12389))

* Deprecated the require path `active_support/core_ext/object/to_json`. Require
  `active_support/core_ext/object/json` instead. ([Pull Request](https://github.com/rails/rails/pull/12203))

* Deprecated `ActiveSupport::JSON::Encoding::CircularReferenceError`. This feature
  has been extracted into the [activesupport-json_encoder](https://github.com/rails/activesupport-json_encoder)
  gem.
  ([Pull Request](https://github.com/rails/rails/pull/12785) /
  [More Details](upgrading_ruby_on_rails.html#changes-in-json-handling))

* Deprecated `ActiveSupport.encode_big_decimal_as_string` option. This feature has
  been extracted into the [activesupport-json_encoder](https://github.com/rails/activesupport-json_encoder)
  gem.
  ([Pull Request](https://github.com/rails/rails/pull/13060) /
  [More Details](upgrading_ruby_on_rails.html#changes-in-json-handling))

* Deprecate custom `BigDecimal`
  serialization. ([Pull Request](https://github.com/rails/rails/pull/13911))

### Notable changes

* `ActiveSupport`'s JSON encoder has been rewritten to take advantage of the
  JSON gem rather than doing custom encoding in pure-Ruby.
  ([Pull Request](https://github.com/rails/rails/pull/12183) /
  [More Details](upgrading_ruby_on_rails.html#changes-in-json-handling))

* Improved compatibility with the JSON gem.
  ([Pull Request](https://github.com/rails/rails/pull/12862) /
  [More Details](upgrading_ruby_on_rails.html#changes-in-json-handling))

* Added `ActiveSupport::Testing::TimeHelpers#travel` and `#travel_to`. These
  methods change current time to the given time or duration by stubbing
  `Time.now` and `Date.today`.

* Added `ActiveSupport::Testing::TimeHelpers#travel_back`. This method returns
  the current time to the original state, by removing the stubs added by `travel`
  and `travel_to`. ([Pull Request](https://github.com/rails/rails/pull/13884))

* Added `Numeric#in_milliseconds`, like `1.hour.in_milliseconds`, so we can feed
  them to JavaScript functions like
  `getTime()`. ([Commit](https://github.com/rails/rails/commit/423249504a2b468d7a273cbe6accf4f21cb0e643))

* Added `Date#middle_of_day`, `DateTime#middle_of_day` and `Time#middle_of_day`
  methods. Also added `midday`, `noon`, `at_midday`, `at_noon` and
  `at_middle_of_day` as
  aliases. ([Pull Request](https://github.com/rails/rails/pull/10879))

* Added `Date#all_week/month/quarter/year` for generating date
  ranges. ([Pull Request](https://github.com/rails/rails/pull/9685))

* Added `Time.zone.yesterday` and
  `Time.zone.tomorrow`. ([Pull Request](https://github.com/rails/rails/pull/12822))

* Added `String#remove(pattern)` as a short-hand for the common pattern of
  `String#gsub(pattern,'')`. ([Commit](https://github.com/rails/rails/commit/5da23a3f921f0a4a3139495d2779ab0d3bd4cb5f))

* Added `Hash#compact` and `Hash#compact!` for removing items with nil value
  from hash. ([Pull Request](https://github.com/rails/rails/pull/13632))

* `blank?` and `present?` commit to return
  singletons. ([Commit](https://github.com/rails/rails/commit/126dc47665c65cd129967cbd8a5926dddd0aa514))

* Default the new `I18n.enforce_available_locales` config to `true`, meaning
  `I18n` will make sure that all locales passed to it must be declared in the
  `available_locales`
  list. ([Pull Request](https://github.com/rails/rails/pull/13341))

* Introduce `Module#concerning`: a natural, low-ceremony way to separate
  responsibilities within a
  class. ([Commit](https://github.com/rails/rails/commit/1eee0ca6de975b42524105a59e0521d18b38ab81))

* Added `Object#presence_in` to simplify adding values to a permitted list.
  ([Commit](https://github.com/rails/rails/commit/4edca106daacc5a159289eae255207d160f22396))


Credits
-------

See the
[full list of contributors to Rails](https://contributors.rubyonrails.org/) for
the many people who spent many hours making Rails, the stable and robust
framework it is. Kudos to all of them.
