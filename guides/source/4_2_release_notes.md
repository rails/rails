Ruby on Rails 4.2 Release Notes
===============================

Highlights in Rails 4.2:

* Active Job, Action Mailer #deliver_later
* Adequate Record
* Web Console
* Foreign key support

These release notes cover only the major changes. To know about various bug
fixes and changes, please refer to the change logs or check out the
[list of commits](https://github.com/rails/rails/commits/master) in the main
Rails repository on GitHub.

--------------------------------------------------------------------------------

NOTE: This document is a work in progress, please help to improve this by sending
a [pull request](https://github.com/rails/rails/edit/master/guides/source/4_2_release_notes.md).

Upgrading to Rails 4.2
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 4.1 in case you
haven't and make sure your application still runs as expected before attempting
to upgrade to Rails 4.2. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-4.1-to-rails-4.2)
guide.


Major Features
--------------

### Active Job, Action Mailer #deliver_later

Active Job is a new framework in Rails 4.2. It is an adapter layer on top of
queuing systems like Resque, Delayed Job, Sidekiq, and more. You can write your
jobs to Active Job, and it'll run on all these queues with no changes. (It comes
pre-configured with an inline runner.)

Building on top of Active Job, Action Mailer now comes with a #deliver_later
method, which adds your email to be sent as a job to a queue, so it doesn't
bog down the controller or model.

The new GlobalID library makes it easy to pass Active Record objects to jobs by
serializing them in a generic form. This means you no longer have to manually
pack and unpack your Active Records by passing ids. Just give the job the
straight Active Record object, and it'll serialize it using GlobalID, and
deserialize it at run time.

### Adequate Record

Rails 4.2 comes with a performance improvement feature called Adequate Record
for Active Record. A lot of common queries are now up to twice as fast in Rails
4.2!

TODO: add some technical details

### Web Console

New applications generated from Rails 4.2 now comes with the Web Console gem by
default.

Web Console is an IRB console available in the browser. In development mode, you
can go to /console and do your work right there. It will also be made available
on all exception pages and allows you to jump between the different points in
the backtrace.

### Foreign key support

The migration DSL now supports adding and removing foreign keys. They are dumped
to `schema.rb` as well. At this time, only the `mysql`, `mysql2` and `postgresql`
adapters support foreign keys.

```ruby
# add a foreign key to `articles.author_id` referencing `authors.id`
add_foreign_key :articles, :authors

# add a foreign key to `articles.author_id` referencing `users.lng_id`
add_foreign_key :articles, :users, column: :author_id, primary_key: "lng_id"

# remove the foreign key on `accounts.branch_id`
remove_foreign_key :accounts, :branches

# remove the foreign key on `accounts.owner_id`
remove_foreign_key :accounts, column: :owner_id
```

See the API documentation on
[add_foreign_key](http://api.rubyonrails.org/v4.2.0/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-add_foreign_key)
and
[remove_foreign_key](http://api.rubyonrails.org/v4.2.0/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-remove_foreign_key)
for a full description.


Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

*   The `rails application` command has been removed without replacement.
    ([Pull Request](https://github.com/rails/rails/pull/11616))

### Deprecations

*   Deprecated `Rails::Rack::LogTailer` without replacement.
    ([Commit](https://github.com/rails/rails/commit/84a13e019e93efaa8994b3f8303d635a7702dbce))

### Notable changes

*   Introduced `web-console` in the default application Gemfile.
    ([Pull Request](https://github.com/rails/rails/pull/16532))

*   Added a `required` option to the model generator for associations.
    ([Pull Request](https://github.com/rails/rails/pull/16062))

*   Introduced an `after_bundle` callback for use in Rails templates.
    ([Pull Request](https://github.com/rails/rails/pull/16359))

*   Introduced the `x` namespace for defining custom configuration options:

    ```ruby
    # config/environments/production.rb
    config.x.payment_processing.schedule = :daily
    config.x.payment_processing.retries  = 3
    config.x.super_debugger              = true
    ```

    These options are then available through the configuration object:

    ```ruby
    Rails.configuration.x.payment_processing.schedule # => :daily
    Rails.configuration.x.payment_processing.retries  # => 3
    Rails.configuration.x.super_debugger              # => true
    ```

    ([Commit](https://github.com/rails/rails/commit/611849772dd66c2e4d005dcfe153f7ce79a8a7db))

*   Introduced `Rails::Application.config_for` to load a configuration for the
    current environment.

    ```ruby
    # config/exception_notification.yml:
    production:
      url: http://127.0.0.1:8080
      namespace: my_app_production
    development:
      url: http://localhost:3001
      namespace: my_app_development

    # config/production.rb
    MyApp::Application.configure do
      config.middleware.use ExceptionNotifier, config_for(:exception_notification)
    end
    ```

    ([Pull Request](https://github.com/rails/rails/pull/16129))

*   Introduced a `--skip-gems` option in the app generator to skip gems such as
    `turbolinks` and `coffee-rails` that does not have their own specific flags.
    ([Commit](https://github.com/rails/rails/commit/10565895805887d4faf004a6f71219da177f78b7))

*   Introduced a `bin/setup` script to enable automated setup code when
    bootstrapping an application.
    ([Pull Request](https://github.com/rails/rails/pull/15189))

*   Changed default value for `config.assets.digest` to `true` in development.
    ([Pull Request](https://github.com/rails/rails/pull/15155))

*   Introduced an API to register new extensions for `rake notes`.
    ([Pull Request](https://github.com/rails/rails/pull/14379))

*   Introduced `Rails.gem_version` as a convenience method to return `Gem::Version.new(Rails.version)`.
    ([Pull Request](https://github.com/rails/rails/pull/14101))

*   Introduced an `after_bundle` callback in the Rails templates.
    ([Pull Request](https://github.com/rails/rails/pull/16359))


Action Pack
-----------

Please refer to the [Changelog][action-pack] for detailed changes.

### Removals

*   `respond_with` and the class-level `respond_to` were removed from Rails and
    moved to the `responders` gem (version 2.0). Add `gem 'responders', '~> 2.0'`
    to your `Gemfile` to continue using these features.
    ([Pull Request](https://github.com/rails/rails/pull/16526))

*   Removed deprecated `AbstractController::Helpers::ClassMethods::MissingHelperError`
    in favor of `AbstractController::Helpers::MissingHelperError`.
    ([Commit](https://github.com/rails/rails/commit/a1ddde15ae0d612ff2973de9cf768ed701b594e8))

### Deprecations

*   Deprecated `assert_tag`, `assert_no_tag`, `find_tag` and `find_all_tag` in
    favor of `assert_select`.
    ([Commit](https://github.com/rails/rails-dom-testing/commit/b12850bc5ff23ba4b599bf2770874dd4f11bf750))

*   Deprecated support for setting the `:to` option of a router to a symbol or a
    string that does not contain a `#` character:

    ```ruby
    get '/posts', to: MyRackApp    => (No change necessary)
    get '/posts', to: 'post#index' => (No change necessary)
    get '/posts', to: 'posts'      => get '/posts', controller: :posts
    get '/posts', to: :index       => get '/posts', action: :index
    ```

    ([Commit](https://github.com/rails/rails/commit/cc26b6b7bccf0eea2e2c1a9ebdcc9d30ca7390d9))

### Notable changes

*   Rails will now automatically include the template's digest in ETags.
    ([Pull Request](https://github.com/rails/rails/pull/16527))

*   `render nothing: true` or rendering a `nil` body no longer add a single
    space padding to the response body.
    ([Pull Request](https://github.com/rails/rails/pull/14883))

*   Introduced the `always_permitted_parameters` option to configure which
    parameters are permitted globally. The default value of this configuration
    is `['controller', 'action']`.
    ([Pull Request](https://github.com/rails/rails/pull/15933))

*   The `*_filter` family methods have been removed from the documentation. Their
    usage is discouraged in favor of the `*_action` family methods:

    ```
    after_filter          => after_action
    append_after_filter   => append_after_action
    append_around_filter  => append_around_action
    append_before_filter  => append_before_action
    around_filter         => around_action
    before_filter         => before_action
    prepend_after_filter  => prepend_after_action
    prepend_around_filter => prepend_around_action
    prepend_before_filter => prepend_before_action
    skip_after_filter     => skip_after_action
    skip_around_filter    => skip_around_action
    skip_before_filter    => skip_before_action
    skip_filter           => skip_action_callback
    ```

    If your application is depending on these methods, you should use the
    replacement `*_action` methods instead. These methods will be deprecated in
    the future and eventually removed from Rails.

    (Commit [1](https://github.com/rails/rails/commit/6c5f43bab8206747a8591435b2aa0ff7051ad3de),
    [2](https://github.com/rails/rails/commit/489a8f2a44dc9cea09154ee1ee2557d1f037c7d4))

*   Added HTTP method `MKCALENDAR` from RFC-4791
    ([Pull Request](https://github.com/rails/rails/pull/15121))

*   `*_fragment.action_controller` notifications now include the controller and action name
    in the payload.
    ([Pull Request](https://github.com/rails/rails/pull/14137))

*   Segments that are passed into URL helpers are now automatically escaped.
    ([Commit](https://github.com/rails/rails/commit/5460591f0226a9d248b7b4f89186bd5553e7768f))

*   Improved the Routing Error page with fuzzy matching for route search.
    ([Pull Request](https://github.com/rails/rails/pull/14619))

*   Added an option to disable logging of CSRF failures.
    ([Pull Request](https://github.com/rails/rails/pull/14280))


Action View
-------------

Please refer to the [Changelog][action-view] for detailed changes.

### Deprecations

*   Deprecated `AbstractController::Base.parent_prefixes`.
    Override `AbstractController::Base.local_prefixes` when you want to change
    where to find views.
    ([Pull Request](https://github.com/rails/rails/pull/15026))

*   Deprecated `ActionView::Digestor#digest(name, format, finder, options = {})`.
    Arguments should be passed as a hash instead.
    ([Pull Request](https://github.com/rails/rails/pull/14243))

### Notable changes

*   Introduced a `#{partial_name}_iteration` special local variable for use with
    partials that are rendered with a collection. It provides access to the
    current state of the iteration via the `#index`, `#size`, `#first?` and
    `#last?` methods.
    ([Pull Request](https://github.com/rails/rails/pull/7698))

*   The form helpers no longer generate a `<div>` element with inline CSS around
    the hidden fields.
    ([Pull Request](https://github.com/rails/rails/pull/14738))


Action Mailer
-------------

Please refer to the [Changelog][action-mailer] for detailed changes.

### Deprecations

*   Deprecated `*_path` helpers in mailers. Always use `*_url` helpers instead.
    ([Pull Request](https://github.com/rails/rails/pull/15840))

### Notable changes

*   Introduced `deliver_later` which enqueues a job on the application's queue
    to deliver the mailer asynchronously.
    ([Pull Request](https://github.com/rails/rails/pull/16485))

*   Added the `show_previews` configuration option for enabling mailer previews
    outside of the development environment.
    ([Pull Request](https://github.com/rails/rails/pull/15970))


Active Record
-------------

Please refer to the
[Changelog](https://github.com/rails/rails/blob/4-2-stable/activerecord/CHANGELOG.md)
for detailed changes.

### Removals

*   Removed `cache_attributes` and friends. All attributes are cached.
    ([Pull Request](https://github.com/rails/rails/pull/15429))

*   Removed deprecated method `ActiveRecord::Base.quoted_locking_column`.
    ([Pull Request](https://github.com/rails/rails/pull/15612))

*   Removed deprecated `ActiveRecord::Migrator.proper_table_name`. Use the
    `proper_table_name` instance method on `ActiveRecord::Migration` instead.
    ([Pull Request](https://github.com/rails/rails/pull/15512))

*   Removed unused `:timestamp` type. Transparently alias it to `:datetime`
    in all cases. Fixes inconsistencies when column types are sent outside of
    `ActiveRecord`, such as for XML Serialization.
    ([Pull Request](https://github.com/rails/rails/pull/15184))

### Deprecations

*   Deprecated swallowing of errors inside `after_commit` and `after_rollback`.
    ([Pull Request](https://github.com/rails/rails/pull/16537))

*   Deprecated calling `DatabaseTasks.load_schema` without a connection. Use
    `DatabaseTasks.load_schema_current` instead.
    ([Commit](https://github.com/rails/rails/commit/f15cef67f75e4b52fd45655d7c6ab6b35623c608))

*   Deprecated `Reflection#source_macro` without replacement as it is no longer
    needed in Active Record.
    ([Pull Request](https://github.com/rails/rails/pull/16373))

*   Deprecated broken support for automatic detection of counter caches on
    `has_many :through` associations. You should instead manually specify the
    counter cache on the `has_many` and `belongs_to` associations for the
    through records.
    ([Pull Request](https://github.com/rails/rails/pull/15754))

*   Deprecated `serialized_attributes` without replacement.
    ([Pull Request](https://github.com/rails/rails/pull/15704))

*   Deprecated returning `nil` from `column_for_attribute` when no column
    exists. It will return a null object in Rails 5.0
    ([Pull Request](https://github.com/rails/rails/pull/15878))

*   Deprecated using `.joins`, `.preload` and `.eager_load` with associations
    that depends on the instance state (i.e. those defined with a scope that
    takes an argument) without replacement.
    ([Commit](https://github.com/rails/rails/commit/ed56e596a0467390011bc9d56d462539776adac1))

*   Deprecated passing Active Record objects to `.find` or `.exists?`. Call
    `#id` on the objects first.
    (Commit [1](https://github.com/rails/rails/commit/d92ae6ccca3bcfd73546d612efaea011270bd270),
    [2](https://github.com/rails/rails/commit/d35f0033c7dec2b8d8b52058fb8db495d49596f7))

*   Deprecated half-baked support for PostgreSQL range values with excluding
    beginnings. We currently map PostgreSQL ranges to Ruby ranges. This conversion
    is not fully possible because the Ruby range does not support excluded
    beginnings.

    The current solution of incrementing the beginning is not correct
    and is now deprecated. For subtypes where we don't know how to increment
    (e.g. `#succ` is not defined) it will raise an `ArgumentError` for ranges
    with excluding beginnings.

    ([Commit](https://github.com/rails/rails/commit/91949e48cf41af9f3e4ffba3e5eecf9b0a08bfc3))

### Notable changes

*   The PostgreSQL adapter now supports the `JSONB` datatype in PostgreSQL 9.4+.
    ([Pull Request](https://github.com/rails/rails/pull/16220))

*   The `#references` method in migrations now supports a `type` option for
    specifying the type of the foreign key (e.g. `:uuid`).
    ([Pull Request](https://github.com/rails/rails/pull/16231))

*   Added a `:required` option to singular associations, which defines a
    presence validation on the association.
    ([Pull Request](https://github.com/rails/rails/pull/16056))

*   Introduced `ActiveRecord::Base#validate!` that raises `RecordInvalid` if the
    record is invalid.
    ([Pull Request](https://github.com/rails/rails/pull/8639))

*   `ActiveRecord::Base#reload` now behaves the same as `m = Model.find(m.id)`,
    meaning that it no longer retains the extra attributes from custom
    `select`s.
    ([Pull Request](https://github.com/rails/rails/pull/15866))

*   Introduced the `bin/rake db:purge` task to empty the database for the
    current environment.
    ([Commit](https://github.com/rails/rails/commit/e2f232aba15937a4b9d14bd91e0392c6d55be58d))

*   `ActiveRecord::Dirty` now detects in-place changes to mutable values.
    Serialized attributes on ActiveRecord models will no longer save when
    unchanged. This also works with other types such as string columns and json
    columns on PostgreSQL.
    (Pull Requests [1](https://github.com/rails/rails/pull/15674),
    [2](https://github.com/rails/rails/pull/15786),
    [3](https://github.com/rails/rails/pull/15788))

*   Added support for `#pretty_print` in `ActiveRecord::Base` objects.
    ([Pull Request](https://github.com/rails/rails/pull/15172))

*   PostgreSQL and SQLite adapters no longer add a default limit of 255
    characters on string columns.
    ([Pull Request](https://github.com/rails/rails/pull/14579))

*   `sqlite3:///some/path` now resolves to the absolute system path
    `/some/path`. For relative paths, use `sqlite3:some/path` instead.
    (Previously, `sqlite3:///some/path` resolved to the relative path
    `some/path`. This behaviour was deprecated on Rails 4.1.)
    ([Pull Request](https://github.com/rails/rails/pull/14569))

*   Introduced `#validate` as an alias for `#valid?`.
    ([Pull Request](https://github.com/rails/rails/pull/14456))

*   `#touch` now accepts multiple attributes to be touched at once.
    ([Pull Request](https://github.com/rails/rails/pull/14423))

*   Added support for fractional seconds for MySQL 5.6 and above.
    (Pull Request [1](https://github.com/rails/rails/pull/8240),
    [2](https://github.com/rails/rails/pull/14359))

*   Added support for the `citext` column type in PostgreSQL adapter.
    ([Pull Request](https://github.com/rails/rails/pull/12523))

*   Added support for user-created range types in PostgreSQL adapter.
    ([Commit](https://github.com/rails/rails/commit/4cb47167e747e8f9dc12b0ddaf82bdb68c03e032))


Active Model
------------

Please refer to the [Changelog][active-model] for detailed changes.

### Removals

*   Removed deprecated `Validator#setup` without replacement.
    ([Pull Request](https://github.com/rails/rails/pull/10716))

### Deprecations

*   Deprecated reset_#{attribute} in favor of restore_#{attribute}.
    ([Pull Request](https://github.com/rails/rails/pull/16180))

*   Deprecated ActiveModel::Dirty#reset_changes in favor of #clear_changes_information.
    ([Pull Request](https://github.com/rails/rails/pull/16180))

### Notable changes

*   Introduced the `restore_attributes` method in `ActiveModel::Dirty` to restore
    the changed (dirty) attributes to their previous values.
    (Pull Request [1](https://github.com/rails/rails/pull/14861), [2](https://github.com/rails/rails/pull/16180))

*   `has_secure_password` no longer disallow blank passwords (i.e. passwords
    that contains only spaces) by default.
    ([Pull Request](https://github.com/rails/rails/pull/16412))

*   `has_secure_password` now verifies that the given password is less than 72
    characters if validations are enabled.
    ([Pull Request](https://github.com/rails/rails/pull/15708))

*   Introduced `#validate` as an alias for `#valid?`.
    ([Pull Request](https://github.com/rails/rails/pull/14456))


Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

### Removals

*   Removed deprecated `Numeric#ago`, `Numeric#until`, `Numeric#since`,
    `Numeric#from_now`.
    ([Commit](https://github.com/rails/rails/commit/f1eddea1e3f6faf93581c43651348f48b2b7d8bb))

*   Removed deprecated string based terminators for `ActiveSupport::Callbacks`.
    ([Pull Request](https://github.com/rails/rails/pull/15100))

### Deprecations

*   Deprecated `Kernel#silence_stderr`, `Kernel#capture` and `Kernel#quietly`
    without replacement.
    ([Pull Request](https://github.com/rails/rails/pull/13392))

*   Deprecated `Class#superclass_delegating_accessor`, use
    `Class#class_attribute` instead.
    ([Pull Request](https://github.com/rails/rails/pull/14271))

*   Deprecated `ActiveSupport::SafeBuffer#prepend!` as
    `ActiveSupport::SafeBuffer#prepend` now performs the same function.
    ([Pull Request](https://github.com/rails/rails/pull/14529))

### Notable changes

*   The `travel_to` test helper now truncates the `usec` component to 0.
    ([Commit](https://github.com/rails/rails/commit/9f6e82ee4783e491c20f5244a613fdeb4024beb5))

*   `ActiveSupport::TestCase` now randomizes the order that test cases are ran
    by default.
    ([Commit](https://github.com/rails/rails/commit/6ffb29d24e05abbd9ffe3ea974140d6c70221807))

*   Introduced `Object#itself` as an identity function.
    (Commit [1](https://github.com/rails/rails/commit/702ad710b57bef45b081ebf42e6fa70820fdd810),
    [2](https://github.com/rails/rails/commit/64d91122222c11ad3918cc8e2e3ebc4b0a03448a))

*   `Object#with_options` can now be used without an explicit receiver.
    ([Pull Request](https://github.com/rails/rails/pull/16339))

*   Introduced `String#truncate_words` to truncate a string by a number of words.
    ([Pull Request](https://github.com/rails/rails/pull/16190))

*   Added `Hash#transform_values` and `Hash#transform_values!` to simplify a
    common pattern where the values of a hash must change, but the keys are left
    the same.
    ([Pull Request](https://github.com/rails/rails/pull/15819))

*   The `humanize` inflector helper now strips any leading underscores.
    ([Commit](https://github.com/rails/rails/commit/daaa21bc7d20f2e4ff451637423a25ff2d5e75c7))

*   Introduced `Concern#class_methods` as an alternative to
    `module ClassMethods`, as well as `Kernel#concern` to avoid the
    `module Foo; extend ActiveSupport::Concern; end` boilerplate.
    ([Commit](https://github.com/rails/rails/commit/b16c36e688970df2f96f793a759365b248b582ad))


Credits
-------

See the
[full list of contributors to Rails](http://contributors.rubyonrails.org/) for
the many people who spent many hours making Rails the stable and robust
framework it is today. Kudos to all of them.

[railties]:       https://github.com/rails/rails/blob/4-2-stable/railties/CHANGELOG.md
[action-pack]:    https://github.com/rails/rails/blob/4-2-stable/actionpack/CHANGELOG.md
[action-view]:    https://github.com/rails/rails/blob/4-2-stable/actionview/CHANGELOG.md
[action-mailer]:  https://github.com/rails/rails/blob/4-2-stable/actionmailer/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/4-2-stable/activerecord/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/4-2-stable/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/4-2-stable/activesupport/CHANGELOG.md
