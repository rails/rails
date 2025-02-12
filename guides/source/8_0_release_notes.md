**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Ruby on Rails 8.0 Release Notes
===============================

Highlights in Rails 8.0:

--------------------------------------------------------------------------------

Upgrading to Rails 8.0
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 7.2 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 8.0. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-7-2-to-rails-8-0)
guide.

Major Features
--------------

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Removals

*   Remove deprecated `config.read_encrypted_secrets`.

*   Remove deprecated file `rails/console/app`.

*   Remove deprecated file `rails/console/helpers`.

*   Remove deprecated support to extend Rails console through `Rails::ConsoleMethods`.

### Deprecations

*   Deprecate requiring `"rails/console/methods"`.

*   Deprecate modifying `STATS_DIRECTORIES` in favor of
    `Rails::CodeStatistics.registery_directory`.

*   Deprecate `bin/rake stats` in favor of `bin/rails stats`.

### Notable changes

*   Set `Regexp.timeout` to `1`s by default to improve security over Regexp Denial-of-Service attacks.

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

*   Remove `Rails.application.config.action_controller.allow_deprecated_parameters_hash_equality`.

### Deprecations

*   Deprecate drawing routes with multiple paths to make routing faster.

### Notable changes

Action View
-----------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

*   Remove deprecated support to passing `nil` to the `model:` argument of `form_with`.

*   Remove deprecated support to passing a content to void tag elements on the `tag` builder.

### Deprecations

### Notable changes

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

*   Remove deprecated `config.active_record.commit_transaction_on_non_local_return`.

*   Remove deprecated `config.active_record.allow_deprecated_singular_associations_name`.

*   Remove deprecated support to finding database adapters that aren't registered to Active Record.

*   Remove deprecated support for defining `enum` with keyword arguments.

*   Remove deprecated `config.active_record.warn_on_records_fetched_greater_than`.

*   Remove deprecated `config.active_record.sqlite3_deprecated_warning`.

*   Remove deprecated `ActiveRecord::ConnectionAdapters::ConnectionPool#connection`.

*   Remove deprecated support to passing a database name to `cache_dump_filename`.

*   Remove deprecated support to setting `ENV["SCHEMA_CACHE"]`.

### Deprecations

*   Deprecate the `retries` option for the `SQLite3Adapter` in favor of
    `timeout`.

### Notable changes

Active Storage
--------------

Please refer to the [Changelog][active-storage] for detailed changes.

### Removals

### Deprecations

*    Deprecate the Azure backend for Active Storage.

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

*   Remove deprecated `ActiveSupport::ProxyObject`.

*   Remove deprecated support to setting `attr_internal_naming_format` with a `@` prefix.

*   Remove deprecated support to passing an array of strings to `ActiveSupport::Deprecation#warn`.

### Deprecations

*   Deprecate `Benchmark.ms`.

*   Deprecate addition and `since` between two `Time` and `ActiveSupport::TimeWithZone`.

### Notable changes

Active Job
----------

Please refer to the [Changelog][active-job] for detailed changes.

### Removals

*   Remove deprecated `config.active_job.use_big_decimal_serializer`.

### Deprecations

*   Deprecate `enqueue_after_transaction_commit`.

*   Deprecate internal `SuckerPunch` adapter in favor of the adapter included
    with the `sucker_punch` gem.

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

[railties]:       https://github.com/rails/rails/blob/8-0-stable/railties/CHANGELOG.md
[action-pack]:    https://github.com/rails/rails/blob/8-0-stable/actionpack/CHANGELOG.md
[action-view]:    https://github.com/rails/rails/blob/8-0-stable/actionview/CHANGELOG.md
[action-mailer]:  https://github.com/rails/rails/blob/8-0-stable/actionmailer/CHANGELOG.md
[action-cable]:   https://github.com/rails/rails/blob/8-0-stable/actioncable/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/8-0-stable/activerecord/CHANGELOG.md
[active-storage]: https://github.com/rails/rails/blob/8-0-stable/activestorage/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/8-0-stable/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/8-0-stable/activesupport/CHANGELOG.md
[active-job]:     https://github.com/rails/rails/blob/8-0-stable/activejob/CHANGELOG.md
[action-text]:    https://github.com/rails/rails/blob/8-0-stable/actiontext/CHANGELOG.md
[action-mailbox]: https://github.com/rails/rails/blob/8-0-stable/actionmailbox/CHANGELOG.md
[guides]:         https://github.com/rails/rails/blob/8-0-stable/guides/CHANGELOG.md
