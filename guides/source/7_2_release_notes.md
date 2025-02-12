**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Ruby on Rails 7.2 Release Notes
===============================

Highlights in Rails 7.2:

* Development containers configuration for applications.
* Add browser version guard by default.
* Make Ruby 3.1 the new minimum version.
* Default Progressive Web Application (PWA) files.
* Add omakase RuboCop rules by default.
* Add GitHub CI workflow by default to new applications.
* Add Brakeman by default to new applications.
* Set a new default for the Puma thread count.
* Prevent jobs from being scheduled within transactions.
* Per transaction commit and rollback callbacks.
* Enable YJIT by default if running Ruby 3.3+.
* New design for the Rails guides.
* Setup jemalloc in default Dockerfile to optimize memory allocation.
* Suggest puma-dev configuration in bin/setup.

These release notes cover only the major changes. To learn about various bug
fixes and changes, please refer to the changelogs or check out the [list of
commits](https://github.com/rails/rails/commits/7-2-stable) in the main Rails
repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 7.2
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 7.1 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 7.2. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-7-1-to-rails-7-2)
guide.

Major Features
--------------

### Development containers configuration for applications

A [development container](https://containers.dev/) (or dev container for short) allows you to use a container
as a full-featured development environment.

Rails 7.2 adds the ability to generate a development container configuration for your application. This configuration
includes a `.devcontainer` folder with a `Dockerfile`, a `docker-compose.yml` file, and a `devcontainer.json` file.

By default, the dev container contains the following:

* A Redis container for use with Kredis, Action Cable, etc.
* A database (SQLite, Postgres, MySQL or MariaDB)
* A Headless Chrome container for system tests
* Active Storage configured to use the local disk and with preview features working

To generate a new application with a development container, you can run:

```bash
$ rails new myapp --devcontainer
```

For existing applications, a `devcontainer` command is now available:

```bash
$ rails devcontainer
```

For more information, see the [Getting Started with Dev Containers](getting_started_with_devcontainer.html) guide.

### Add browser version guard by default

Rails now adds the ability to specify the browser versions that will be allowed to access all actions
(or some, as limited by `only:` or `except:`).

Only browsers matched in the hash or named set passed to `versions:` will be blocked if they're below the versions
specified.

This means that all other unknown browsers, as well as agents that aren't reporting a user-agent header, will be allowed access.

A browser that's blocked will by default be served the file in `public/406-unsupported-browser.html` with a HTTP status
code of "406 Not Acceptable".

Examples:

```ruby
class ApplicationController < ActionController::Base
  # Allow only browsers natively supporting webp images, web push, badges, import maps, CSS nesting + :has
  allow_browser versions: :modern
end

class ApplicationController < ActionController::Base
  # All versions of Chrome and Opera will be allowed, but no versions of "internet explorer" (ie). Safari needs to be 16.4+ and Firefox 121+.
  allow_browser versions: { safari: 16.4, firefox: 121, ie: false }
end

class MessagesController < ApplicationController
  # In addition to the browsers blocked by ApplicationController, also block Opera below 104 and Chrome below 119 for the show action.
  allow_browser versions: { opera: 104, chrome: 119 }, only: :show
end
```

Newly generated applications have this guard set in `ApplicationController`.

For more information, see the [allow_browser](https://api.rubyonrails.org/classes/ActionController/AllowBrowser/ClassMethods.html#method-i-allow_browser)
documentation.

### Make Ruby 3.1 the new minimum version

Until now, Rails only dropped compatibility with older Rubies on new majors version.
We are changing this policy because it causes us to keep compatibility with long
unsupported versions of Ruby or to bump the Rails major version more often, and to
drop multiple Ruby versions at once when we bump the major.

We will now drop Ruby versions that are end-of-life on minor Rails versions at the time of the release.

For Rails 7.2, Ruby 3.1 is the new minimum version.

### Default Progressive Web Application (PWA) files

In preparation to better supporting the creation of PWA applications with Rails, we now generate default PWA files for the manifest
and service worker, which are served from `app/views/pwa` and can be dynamically rendered through ERB. Those files
are mounted explicitly at the root with default routes in the generated routes file.

For more information, see the [pull request adding the feature](https://github.com/rails/rails/pull/50528).

### Add omakase RuboCop rules by default

Rails applications now come with [RuboCop](https://rubocop.org/) configured with a set of rules from [rubocop-rails-omakase](https://github.com/rails/rubocop-rails-omakase) by default.

Ruby is a beautifully expressive language that not only tolerates many different dialects, but celebrates their
diversity. It was never meant as a language to be written exclusively in a single style across all libraries,
frameworks, or applications. If you or your team has developed a particular house style that brings you joy,
you should cherish that.

This collection of RuboCop styles is for those who haven't committed to any specific dialect already. Who would just
like to have a reasonable starting point, and who will benefit from some default rules to at least start a consistent
approach to Ruby styling.

These specific rules aren't right or wrong, but merely represent the idiosyncratic aesthetic sensibilities of Rails'
creator. Use them whole, use them as a starting point, use them as inspiration, or however you see fit.

### Add GitHub CI workflow by default to new applications

Rails now adds a default GitHub CI workflow file to new applications. This will get especially newcomers off to a good
start with automated scanning, linting, and testing. We find that a natural continuation for the modern age of what
we've done since the start with unit tests.

It's of course true that GitHub Actions are a commercial cloud product for private repositories after you've used the
free tokens. But given the relationship between GitHub and Rails, the overwhelming default nature of the platform for
newcomers, and the value of teaching newcomers good CI habits, we find this to be an acceptable trade-off.

### Add Brakeman by default to new applications

[Brakeman](https://brakemanscanner.org/) is a great way to prevent common security vulnerabilities in Rails from going
into production.

New applications come with Brakeman installed and combined with the GitHub CI workflow, it will run automatically on
every push.

### Set a new default for the Puma thread count

Rails changed the default number of threads in Puma from 5 to 3.

Due to the nature of well-optimized Rails applications, with quick SQL queries and slow 3rd-party calls running via jobs,
Ruby can spend a significant amount of time waiting for the Global VM Lock (GVL) to release when the thread count is too
high, which is hurting latency (request response time).

After careful consideration, investigation, and based on battle-tested experience from applications running in
production, we decided that a default of 3 threads is a good balance between concurrency and performance.

You can follow a very detailed discussion about this change in [the issue](https://github.com/rails/rails/issues/50450).

### Prevent jobs from being scheduled within transactions

A common mistake with Active Job is to enqueue jobs from inside a transaction, causing them to potentially be picked
and ran by another process, before the transaction is committed, which result in various errors.

```ruby
Topic.transaction do
  topic = Topic.create

  NewTopicNotificationJob.perform_later(topic)
end
```

Now Active Job will automatically defer the enqueuing to after the transaction is committed, and drop the job if the
transaction is rolled back.

Various queue implementations can chose to disable this behavior, and users can disable it, or force it on a per job
basis:

```ruby
class NewTopicNotificationJob < ApplicationJob
  self.enqueue_after_transaction_commit = :never
end
```

### Per transaction commit and rollback callbacks

This is now possible due to a new feature that allows registering transaction callbacks outside of a record.

`ActiveRecord::Base.transaction` now yields an `ActiveRecord::Transaction` object, which allows registering callbacks
on it.

```ruby
Article.transaction do |transaction|
  article.update(published: true)

  transaction.after_commit do
    PublishNotificationMailer.with(article: article).deliver_later
  end
end
```

`ActiveRecord::Base.current_transaction` was also added to allow to register callbacks on it.

```ruby
Article.current_transaction.after_commit do
  PublishNotificationMailer.with(article: article).deliver_later
end
```

And finally, `ActiveRecord.after_all_transactions_commit` was added, for code that may run either inside or outside a
transaction and needs to perform work after the state changes have been properly persisted.

```ruby
def publish_article(article)
  article.update(published: true)

  ActiveRecord.after_all_transactions_commit do
    PublishNotificationMailer.with(article: article).deliver_later
  end
end
```

See [#51474](https://github.com/rails/rails/pull/51474) and [#51426](https://github.com/rails/rails/pull/51426) for more information:

### Enable YJIT by default if running Ruby 3.3+

YJIT is Ruby's JIT compiler that is available in CRuby since Ruby 3.1. It can provide significant performance
improvements for Rails applications, offering 15-25% latency improvements.

In Rails 7.2, YJIT is enabled by default if running Ruby 3.3 or newer.

You can disable YJIT by setting:

```ruby
Rails.application.config.yjit = false
```

### New design for the Rails guides

When Rails 7.0 landed in December 2021, it came with a fresh new homepage and a new boot screen. The design of the
guides, however, has remained largely untouched since 2009 - a point which hasn’t gone unnoticed (we heard your feedback).

With all of the work right now going into removing complexity from the Rails framework and making the documentation
consistent, clear, and up-to-date, it was time to tackle the design of the guides and make them equally modern, simple,
and fresh.

We worked with UX designer [John Athayde](https://meticulous.com/) to take the look and feel of the homepage and
transfer that over to the Rails guides to make them clean, sleek, and up-to-date.

The layout will remain the same, but from today you will see the following changes reflected in the guides:

* Cleaner, less busy design.
* Fonts, color scheme, and logo more consistent with the home page.
* Updated iconography.
* Simplified navigation.
* Sticky "Chapters" navbar when scrolling.

See the [announcement blog post for some before/after images](https://rubyonrails.org/2024/3/20/rails-guides-get-a-facelift).

### Setup jemalloc in default Dockerfile to optimize memory allocation

[Ruby's use of `malloc` can create memory fragmentation problems, especially when using multiple threads](https://www.speedshop.co/2017/12/04/malloc-doubles-ruby-memory.html)
like Puma does. Switching to an allocator that uses different patterns to avoid fragmentation can decrease memory usage
by a substantial margin.

Rails 7.2 now includes [jemalloc](https://jemalloc.net/) in the default Dockerfile to optimize memory allocation.

### Suggest puma-dev configuration in bin/setup

[Puma-dev](https://github.com/puma/puma-dev) is the golden path for developing multiple Rails applications locally, if you're not using Docker.

Rails now suggests how to get that setup in a new comment you'll find in `bin/setup`.

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

*   Remove deprecated `Rails::Generators::Testing::Behaviour`.

*   Remove deprecated `Rails.application.secrets`.

*   Remove deprecated `Rails.config.enable_dependency_loading`.

*   Remove deprecated `find_cmd_and_exec` console helper.

*   Remove support for `oracle`, `sqlserver`, and JRuby specific database adapters from the `new`
    and `db:system:change` `rails` commands.

*   Remove `config.public_file_server.enabled` option from the generators.

### Deprecations

### Notable changes

*   Add RuboCop with rules from [rubocop-rails-omakase](https://github.com/rails/rubocop-rails-omakase)
    by default in both new applications and plugins.

*   Add Brakeman with default configuration for security checks in new applications.

*   Add GitHub CI files for Dependabot, Brakeman, RuboCop, and running tests by default for new applications and plugins.

*   YJIT is now enabled by default for new applications running on Ruby 3.3+.

*   Generate a `.devcontainer` folder for running the application in a container with Visual Studio Code.

    ```bash
    $ rails new myapp --devcontainer
    ```

*   Introduce `Rails::Generators::Testing::Assertions#assert_initializer` to test initializers.

*   System tests now use Headless Chrome by default for new applications.

*   Support the `BACKTRACE` environment variable to turn off backtrace cleaning in normal server runnings.
    Previously, this was only available for testing.

*   Add default Progressive Web App (PWA) files for the manifest and service worker, served from `app/views/pwa`,
    and make them dynamically renderable through ERB.

Action Cable
------------

Please refer to the [Changelog][action-cable] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action Pack
-----------

Please refer to the [Changelog][action-pack] for detailed changes.

### Removals

*   Remove deprecated constant `ActionDispatch::IllegalStateError`.

*   Remove deprecated constant `AbstractController::Helpers::MissingHelperError`.

*   Remove deprecated comparison between `ActionController::Parameters` and `Hash`.

*   Remove deprecated `Rails.application.config.action_dispatch.return_only_request_media_type_on_content_type`.

*   Remove deprecated `speaker`, `vibrate`, and `vr` permissions policy directives.

*   Remove deprecated support to set `Rails.application.config.action_dispatch.show_exceptions` to `true` and `false`.

### Deprecations

*   Deprecate `Rails.application.config.action_controller.allow_deprecated_parameters_hash_equality`.

### Notable changes

Action View
-----------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

*   Remove deprecated `@rails/ujs` in favor of Turbo.

### Deprecations

*  Deprecate passing content to void elements when using `tag.br` type tag builders.

### Notable changes

Action Mailer
-------------

Please refer to the [Changelog][action-mailer] for detailed changes.

### Removals

*   Remove deprecated `config.action_mailer.preview_path`.

*   Remove deprecated params via `:args` for `assert_enqueued_email_with`.

### Deprecations

### Notable changes

Active Record
-------------

Please refer to the [Changelog][active-record] for detailed changes.

### Removals

*   Remove deprecated `Rails.application.config.active_record.suppress_multiple_database_warning`.

*   Remove deprecated support to call `alias_attribute` with non-existent attribute names.

*   Remove deprecated `name` argument from `ActiveRecord::Base.remove_connection`.

*   Remove deprecated `ActiveRecord::Base.clear_active_connections!`.

*   Remove deprecated `ActiveRecord::Base.clear_reloadable_connections!`.

*   Remove deprecated `ActiveRecord::Base.clear_all_connections!`.

*   Remove deprecated `ActiveRecord::Base.flush_idle_connections!`.

*   Remove deprecated `ActiveRecord::ActiveJobRequiredError`.

*   Remove deprecated support to define `explain` in the connection adapter with 2 arguments.

*   Remove deprecated `ActiveRecord::LogSubscriber.runtime` method.

*   Remove deprecated `ActiveRecord::LogSubscriber.runtime=` method.

*   Remove deprecated `ActiveRecord::LogSubscriber.reset_runtime` method.

*   Remove deprecated `ActiveRecord::Migration.check_pending` method.

*   Remove deprecated support to passing `SchemaMigration` and `InternalMetadata` classes as arguments to
    `ActiveRecord::MigrationContext`.

*   Remove deprecated behavior to support referring to a singular association by its plural name.

*   Remove deprecated `TestFixtures.fixture_path`.

*   Remove deprecated support to `ActiveRecord::Base#read_attribute(:id)` to return the custom primary key value.

*   Remove deprecated support to passing coder and class as second argument to `serialize`.

*   Remove deprecated `#all_foreign_keys_valid?` from database adapters.

*   Remove deprecated `ActiveRecord::ConnectionAdapters::SchemaCache.load_from`.

*   Remove deprecated `ActiveRecord::ConnectionAdapters::SchemaCache#data_sources`.

*   Remove deprecated `#all_connection_pools`.

*   Remove deprecated support to apply `#connection_pool_list`, `#active_connections?`, `#clear_active_connections!`,
    `#clear_reloadable_connections!`, `#clear_all_connections!` and `#flush_idle_connections!` to the connections pools
    for the current role when the `role` argument isn't provided.

*   Remove deprecated `ActiveRecord::ConnectionAdapters::ConnectionPool#connection_klass`.

*   Remove deprecated `#quote_bound_value`.

*   Remove deprecated support to quote `ActiveSupport::Duration`.

*   Remove deprecated support to pass `deferrable: true` to `add_foreign_key`.

*   Remove deprecated support to pass `rewhere` to `ActiveRecord::Relation#merge`.

*   Remove deprecated behavior that would rollback a transaction block when exited using `return`, `break` or `throw`.

### Deprecations

*   Deprecate `Rails.application.config.active_record.allow_deprecated_singular_associations_name`

*   Deprecate `Rails.application.config.active_record.commit_transaction_on_non_local_return`

### Notable changes

Active Storage
--------------

Please refer to the [Changelog][active-storage] for detailed changes.

### Removals

*   Remove deprecated `config.active_storage.replace_on_assign_to_many`.

*   Remove deprecated `config.active_storage.silence_invalid_content_types_warning`.

### Deprecations

### Notable changes

Active Model
------------

Please refer to the [Changelog][active-model] for detailed changes.

### Removals

### Deprecations

### Notable changes

Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

### Removals

*   Remove deprecated `ActiveSupport::Notifications::Event#children` and  `ActiveSupport::Notifications::Event#parent_of?`.

*   Remove deprecated support to call the following methods without passing a deprecator:

    - `deprecate`
    - `deprecate_constant`
    - `ActiveSupport::Deprecation::DeprecatedObjectProxy.new`
    - `ActiveSupport::Deprecation::DeprecatedInstanceVariableProxy.new`
    - `ActiveSupport::Deprecation::DeprecatedConstantProxy.new`
    - `assert_deprecated`
    - `assert_not_deprecated`
    - `collect_deprecations`

*   Remove deprecated `ActiveSupport::Deprecation` delegation to instance.

*   Remove deprecated `SafeBuffer#clone_empty`.

*   Remove deprecated `#to_default_s` from `Array`, `Date`, `DateTime` and `Time`.

*   Remove deprecated `:pool_size` and `:pool_timeout` options for the cache storage.

*   Remove deprecated support for `config.active_support.cache_format_version = 6.1`.

*   Remove deprecated constants `ActiveSupport::LogSubscriber::CLEAR` and `ActiveSupport::LogSubscriber::BOLD`.

*   Remove deprecated support to bolding log text with positional boolean in `ActiveSupport::LogSubscriber#color`.

*   Remove deprecated `config.active_support.disable_to_s_conversion`.

*   Remove deprecated `config.active_support.remove_deprecated_time_with_zone_name`.

*   Remove deprecated `config.active_support.use_rfc4122_namespaced_uuids`.

*   Remove deprecated support to passing `Dalli::Client` instances to `MemCacheStore`.

### Deprecations

### Notable changes

Active Job
----------

Please refer to the [Changelog][active-job] for detailed changes.

### Removals

*   Remove deprecated primitive serializer for `BigDecimal` arguments.

*   Remove deprecated support to set numeric values to `scheduled_at` attribute.

*   Remove deprecated `:exponentially_longer` value for the `:wait` in `retry_on`.

### Deprecations

*   Deprecate `Rails.application.config.active_job.use_big_decimal_serialize`.

### Notable changes

Action Text
----------

Please refer to the [Changelog][action-text] for detailed changes.

### Removals

### Deprecations

### Notable changes

Action Mailbox
----------

Please refer to the [Changelog][action-mailbox] for detailed changes.

### Removals

### Deprecations

### Notable changes

Ruby on Rails Guides
--------------------

Please refer to the [Changelog][guides] for detailed changes.

### Notable changes

Credits
-------

See the
[full list of contributors to Rails](https://contributors.rubyonrails.org/)
for the many people who spent many hours making Rails, the stable and robust
framework it is. Kudos to all of them.

[railties]:       https://github.com/rails/rails/blob/7-2-stable/railties/CHANGELOG.md
[action-pack]:    https://github.com/rails/rails/blob/7-2-stable/actionpack/CHANGELOG.md
[action-view]:    https://github.com/rails/rails/blob/7-2-stable/actionview/CHANGELOG.md
[action-mailer]:  https://github.com/rails/rails/blob/7-2-stable/actionmailer/CHANGELOG.md
[action-cable]:   https://github.com/rails/rails/blob/7-2-stable/actioncable/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/7-2-stable/activerecord/CHANGELOG.md
[active-storage]: https://github.com/rails/rails/blob/7-2-stable/activestorage/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/7-2-stable/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/7-2-stable/activesupport/CHANGELOG.md
[active-job]:     https://github.com/rails/rails/blob/7-2-stable/activejob/CHANGELOG.md
[action-text]:    https://github.com/rails/rails/blob/7-2-stable/actiontext/CHANGELOG.md
[action-mailbox]: https://github.com/rails/rails/blob/7-2-stable/actionmailbox/CHANGELOG.md
[guides]:         https://github.com/rails/rails/blob/7-2-stable/guides/CHANGELOG.md
