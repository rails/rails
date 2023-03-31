**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON https://guides.rubyonrails.org.**

Ruby on Rails 5.2 Release Notes
===============================

Highlights in Rails 5.2:

* Active Storage
* Redis Cache Store
* HTTP/2 Early Hints
* Credentials
* Content Security Policy

These release notes cover only the major changes. To learn about various bug
fixes and changes, please refer to the changelogs or check out the [list of
commits](https://github.com/rails/rails/commits/5-2-stable) in the main Rails
repository on GitHub.

--------------------------------------------------------------------------------

Upgrading to Rails 5.2
----------------------

If you're upgrading an existing application, it's a great idea to have good test
coverage before going in. You should also first upgrade to Rails 5.1 in case you
haven't and make sure your application still runs as expected before attempting
an update to Rails 5.2. A list of things to watch out for when upgrading is
available in the
[Upgrading Ruby on Rails](upgrading_ruby_on_rails.html#upgrading-from-rails-5-1-to-rails-5-2)
guide.

Major Features
--------------

### Active Storage

[Pull Request](https://github.com/rails/rails/pull/30020)

[Active Storage](https://github.com/rails/rails/tree/5-2-stable/activestorage)
facilitates uploading files to a cloud storage service like
Amazon S3, Google Cloud Storage, or Microsoft Azure Storage and attaching
those files to Active Record objects. It comes with a local disk-based service
for development and testing and supports mirroring files to subordinate
services for backups and migrations.
You can read more about Active Storage in the
[Active Storage Overview](active_storage_overview.html) guide.

### Redis Cache Store

[Pull Request](https://github.com/rails/rails/pull/31134)

Rails 5.2 ships with built-in Redis cache store.
You can read more about this in the
[Caching with Rails: An Overview](caching_with_rails.html#activesupport-cache-rediscachestore)
guide.

### HTTP/2 Early Hints

[Pull Request](https://github.com/rails/rails/pull/30744)

Rails 5.2 supports [HTTP/2 Early Hints](https://tools.ietf.org/html/rfc8297).
To start the server with Early Hints enabled pass `--early-hints`
to `bin/rails server`.

### Credentials

[Pull Request](https://github.com/rails/rails/pull/30067)

Added `config/credentials.yml.enc` file to store production app secrets.
It allows saving any authentication credentials for third-party services
directly in repository encrypted with a key in the `config/master.key` file or
the `RAILS_MASTER_KEY` environment variable.
This will eventually replace `Rails.application.secrets` and the encrypted
secrets introduced in Rails 5.1.
Furthermore, Rails 5.2
[opens API underlying Credentials](https://github.com/rails/rails/pull/30940),
so you can easily deal with other encrypted configurations, keys, and files.
You can read more about this in the
[Securing Rails Applications](security.html#custom-credentials)
guide.

### Content Security Policy

[Pull Request](https://github.com/rails/rails/pull/31162)

Rails 5.2 ships with a new DSL that allows you to configure a
[Content Security Policy](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy)
for your application. You can configure a global default policy and then
override it on a per-resource basis and even use lambdas to inject per-request
values into the header such as account subdomains in a multi-tenant application.
You can read more about this in the
[Securing Rails Applications](security.html#content-security-policy)
guide.

Railties
--------

Please refer to the [Changelog][railties] for detailed changes.

### Deprecations

*   Deprecate `capify!` method in generators and templates.
    ([Pull Request](https://github.com/rails/rails/pull/29493))

*   Passing the environment's name as a regular argument to the
    `rails dbconsole` and `rails console` commands is deprecated.
    The `-e` option should be used instead.
    ([Commit](https://github.com/rails/rails/commit/48b249927375465a7102acc71c2dfb8d49af8309))

*   Deprecate using subclass of `Rails::Application` to start the Rails server.
    ([Pull Request](https://github.com/rails/rails/pull/30127))

*   Deprecate `after_bundle` callback in Rails plugin templates.
    ([Pull Request](https://github.com/rails/rails/pull/29446))

### Notable changes

*   Added a shared section to `config/database.yml` that will be loaded for
    all environments.
    ([Pull Request](https://github.com/rails/rails/pull/28896))

*   Add `railtie.rb` to the plugin generator.
    ([Pull Request](https://github.com/rails/rails/pull/29576))

*   Clear screenshot files in `tmp:clear` task.
    ([Pull Request](https://github.com/rails/rails/pull/29534))

*   Skip unused components when running `bin/rails app:update`.
    If the initial app generation skipped Action Cable, Active Record, etc.,
    the update task honors those skips too.
    ([Pull Request](https://github.com/rails/rails/pull/29645))

*   Allow passing a custom connection name to the `rails dbconsole`
    command when using a 3-level database configuration.
    Example: `bin/rails dbconsole -c replica`.
    ([Commit](https://github.com/rails/rails/commit/1acd9a6464668d4d54ab30d016829f60b70dbbeb))

*   Properly expand shortcuts for environment's name running the `console`
    and `dbconsole` commands.
    ([Commit](https://github.com/rails/rails/commit/3777701f1380f3814bd5313b225586dec64d4104))

*   Add `bootsnap` to default `Gemfile`.
    ([Pull Request](https://github.com/rails/rails/pull/29313))

*   Support `-` as a platform-agnostic way to run a script from stdin with
    `rails runner`
    ([Pull Request](https://github.com/rails/rails/pull/26343))

*   Add `ruby x.x.x` version to `Gemfile` and create `.ruby-version`
    root file containing the current Ruby version when new Rails applications
    are created.
    ([Pull Request](https://github.com/rails/rails/pull/30016))

*   Add `--skip-action-cable` option to the plugin generator.
    ([Pull Request](https://github.com/rails/rails/pull/30164))

*   Add `git_source` to `Gemfile` for plugin generator.
    ([Pull Request](https://github.com/rails/rails/pull/30110))

*   Skip unused components when running `bin/rails` in Rails plugin.
    ([Commit](https://github.com/rails/rails/commit/62499cb6e088c3bc32a9396322c7473a17a28640))

*   Optimize indentation for generator actions.
    ([Pull Request](https://github.com/rails/rails/pull/30166))

*   Optimize routes indentation.
    ([Pull Request](https://github.com/rails/rails/pull/30241))

*   Add `--skip-yarn` option to the plugin generator.
    ([Pull Request](https://github.com/rails/rails/pull/30238))

*   Support multiple versions arguments for `gem` method of Generators.
    ([Pull Request](https://github.com/rails/rails/pull/30323))

*   Derive `secret_key_base` from the app name in development and test
    environments.
    ([Pull Request](https://github.com/rails/rails/pull/30067))

*   Add `mini_magick` to default `Gemfile` as comment.
    ([Pull Request](https://github.com/rails/rails/pull/30633))

*   `rails new` and `rails plugin new` get `Active Storage` by default.
    Add ability to skip `Active Storage` with `--skip-active-storage`
    and do so automatically when `--skip-active-record` is used.
    ([Pull Request](https://github.com/rails/rails/pull/30101))

Action Cable
------------

Please refer to the [Changelog][action-cable] for detailed changes.

### Removals

*   Removed deprecated evented redis adapter.
    ([Commit](https://github.com/rails/rails/commit/48766e32d31651606b9f68a16015ad05c3b0de2c))

### Notable changes

*   Add support for `host`, `port`, `db` and `password` options in cable.yml
    ([Pull Request](https://github.com/rails/rails/pull/29528))

*   Hash long stream identifiers when using PostgreSQL adapter.
    ([Pull Request](https://github.com/rails/rails/pull/29297))

Action Pack
-----------

Please refer to the [Changelog][action-pack] for detailed changes.

### Removals

*   Remove deprecated `ActionController::ParamsParser::ParseError`.
    ([Commit](https://github.com/rails/rails/commit/e16c765ac6dcff068ff2e5554d69ff345c003de1))

### Deprecations

*   Deprecate `#success?`, `#missing?` and `#error?` aliases of
    `ActionDispatch::TestResponse`.
    ([Pull Request](https://github.com/rails/rails/pull/30104))

### Notable changes

*   Add support for recyclable cache keys with fragment caching.
    ([Pull Request](https://github.com/rails/rails/pull/29092))

*   Change the cache key format for fragments to make it easier to debug key
    churn.
    ([Pull Request](https://github.com/rails/rails/pull/29092))

*   AEAD encrypted cookies and sessions with GCM.
    ([Pull Request](https://github.com/rails/rails/pull/28132))

*   Protect from forgery by default.
    ([Pull Request](https://github.com/rails/rails/pull/29742))

*   Enforce signed/encrypted cookie expiry server side.
    ([Pull Request](https://github.com/rails/rails/pull/30121))

*   Cookies `:expires` option supports `ActiveSupport::Duration` object.
    ([Pull Request](https://github.com/rails/rails/pull/30121))

*   Use Capybara registered `:puma` server config.
    ([Pull Request](https://github.com/rails/rails/pull/30638))

*   Simplify cookies middleware with key rotation support.
    ([Pull Request](https://github.com/rails/rails/pull/29716))

*   Add ability to enable Early Hints for HTTP/2.
    ([Pull Request](https://github.com/rails/rails/pull/30744))

*   Add headless chrome support to System Tests.
    ([Pull Request](https://github.com/rails/rails/pull/30876))

*   Add `:allow_other_host` option to `redirect_back` method.
    ([Pull Request](https://github.com/rails/rails/pull/30850))

*   Make `assert_recognizes` to traverse mounted engines.
    ([Pull Request](https://github.com/rails/rails/pull/22435))

*   Add DSL for configuring Content-Security-Policy header.
    ([Pull Request](https://github.com/rails/rails/pull/31162),
    [Commit](https://github.com/rails/rails/commit/619b1b6353a65e1635d10b8f8c6630723a5a6f1a),
    [Commit](https://github.com/rails/rails/commit/4ec8bf68ff92f35e79232fbd605012ce1f4e1e6e))

*   Register most popular audio/video/font MIME types supported by modern
    browsers.
    ([Pull Request](https://github.com/rails/rails/pull/31251))

*   Changed the default system test screenshot output from `inline` to `simple`.
    ([Commit](https://github.com/rails/rails/commit/9d6e288ee96d6241f864dbf90211c37b14a57632))

*   Add headless firefox support to System Tests.
    ([Pull Request](https://github.com/rails/rails/pull/31365))

*   Add secure `X-Download-Options` and `X-Permitted-Cross-Domain-Policies` to
    default headers set.
    ([Commit](https://github.com/rails/rails/commit/5d7b70f4336d42eabfc403e9f6efceb88b3eff44))

*   Changed the system tests to set Puma as default server only when the
    user haven't specified manually another server.
    ([Pull Request](https://github.com/rails/rails/pull/31384))

*   Add `Referrer-Policy` header to default headers set.
    ([Commit](https://github.com/rails/rails/commit/428939be9f954d39b0c41bc53d85d0d106b9d1a1))

*   Matches behavior of `Hash#each` in `ActionController::Parameters#each`.
    ([Pull Request](https://github.com/rails/rails/pull/27790))

*   Add support for automatic nonce generation for Rails UJS.
    ([Commit](https://github.com/rails/rails/commit/b2f0a8945956cd92dec71ec4e44715d764990a49))

*   Update the default HSTS max-age value to 31536000 seconds (1 year)
    to meet the minimum max-age requirement for https://hstspreload.org/.
    ([Commit](https://github.com/rails/rails/commit/30b5f469a1d30c60d1fb0605e84c50568ff7ed37))

*   Add alias method `to_hash` to `to_h` for `cookies`.
    Add alias method `to_h` to `to_hash` for `session`.
    ([Commit](https://github.com/rails/rails/commit/50a62499e41dfffc2903d468e8b47acebaf9b500))

Action View
-----------

Please refer to the [Changelog][action-view] for detailed changes.

### Removals

*   Remove deprecated Erubis ERB handler.
    ([Commit](https://github.com/rails/rails/commit/7de7f12fd140a60134defe7dc55b5a20b2372d06))

### Deprecations

*   Deprecate `image_alt` helper which used to add default alt text to
    the images generated by `image_tag`.
    ([Pull Request](https://github.com/rails/rails/pull/30213))

### Notable changes

*   Add `:json` type to `auto_discovery_link_tag` to support
    [JSON Feeds](https://jsonfeed.org/version/1).
    ([Pull Request](https://github.com/rails/rails/pull/29158))

*   Add `srcset` option to `image_tag` helper.
    ([Pull Request](https://github.com/rails/rails/pull/29349))

*   Fix issues with `field_error_proc` wrapping `optgroup` and
    select divider `option`.
    ([Pull Request](https://github.com/rails/rails/pull/31088))

*   Change `form_with` to generate ids by default.
    ([Commit](https://github.com/rails/rails/commit/260d6f112a0ffdbe03e6f5051504cb441c1e94cd))

*   Add `preload_link_tag` helper.
    ([Pull Request](https://github.com/rails/rails/pull/31251))

*   Allow the use of callable objects as group methods for grouped selects.
    ([Pull Request](https://github.com/rails/rails/pull/31578))

Action Mailer
-------------

Please refer to the [Changelog][action-mailer] for detailed changes.

### Notable changes

*   Allow Action Mailer classes to configure their delivery job.
    ([Pull Request](https://github.com/rails/rails/pull/29457))

*   Add `assert_enqueued_email_with` test helper.
    ([Pull Request](https://github.com/rails/rails/pull/30695))

Active Record
-------------

Please refer to the [Changelog][active-record] for detailed changes.

### Removals

*   Remove deprecated `#migration_keys`.
    ([Pull Request](https://github.com/rails/rails/pull/30337))

*   Remove deprecated support to `quoted_id` when typecasting
    an Active Record object.
    ([Commit](https://github.com/rails/rails/commit/82472b3922bda2f337a79cef961b4760d04f9689))

*   Remove deprecated argument `default` from `index_name_exists?`.
    ([Commit](https://github.com/rails/rails/commit/8f5b34df81175e30f68879479243fbce966122d7))

*   Remove deprecated support to passing a class to `:class_name`
    on associations.
    ([Commit](https://github.com/rails/rails/commit/e65aff70696be52b46ebe57207ebd8bb2cfcdbb6))

*   Remove deprecated methods `initialize_schema_migrations_table` and
    `initialize_internal_metadata_table`.
    ([Commit](https://github.com/rails/rails/commit/c9660b5777707658c414b430753029cd9bc39934))

*   Remove deprecated method `supports_migrations?`.
    ([Commit](https://github.com/rails/rails/commit/9438c144b1893f2a59ec0924afe4d46bd8d5ffdd))

*   Remove deprecated method `supports_primary_key?`.
    ([Commit](https://github.com/rails/rails/commit/c56ff22fc6e97df4656ddc22909d9bf8b0c2cbb1))

*   Remove deprecated method
    `ActiveRecord::Migrator.schema_migrations_table_name`.
    ([Commit](https://github.com/rails/rails/commit/7df6e3f3cbdea9a0460ddbab445c81fbb1cfd012))

*   Remove deprecated argument `name` from `#indexes`.
    ([Commit](https://github.com/rails/rails/commit/d6b779ecebe57f6629352c34bfd6c442ac8fba0e))

*   Remove deprecated arguments from `#verify!`.
    ([Commit](https://github.com/rails/rails/commit/9c6ee1bed0292fc32c23dc1c68951ae64fc510be))

*   Remove deprecated configuration `.error_on_ignored_order_or_limit`.
    ([Commit](https://github.com/rails/rails/commit/e1066f450d1a99c9a0b4d786b202e2ca82a4c3b3))

*   Remove deprecated method `#scope_chain`.
    ([Commit](https://github.com/rails/rails/commit/ef7784752c5c5efbe23f62d2bbcc62d4fd8aacab))

*   Remove deprecated method `#sanitize_conditions`.
    ([Commit](https://github.com/rails/rails/commit/8f5413b896099f80ef46a97819fe47a820417bc2))

### Deprecations

*   Deprecate `supports_statement_cache?`.
    ([Pull Request](https://github.com/rails/rails/pull/28938))

*   Deprecate passing arguments and block at the same time to
    `count` and `sum` in `ActiveRecord::Calculations`.
    ([Pull Request](https://github.com/rails/rails/pull/29262))

*   Deprecate delegating to `arel` in `Relation`.
    ([Pull Request](https://github.com/rails/rails/pull/29619))

*   Deprecate `set_state` method in `TransactionState`.
    ([Commit](https://github.com/rails/rails/commit/608ebccf8f6314c945444b400a37c2d07f21b253))

*   Deprecate `expand_hash_conditions_for_aggregates` without replacement.
    ([Commit](https://github.com/rails/rails/commit/7ae26885d96daee3809d0bd50b1a440c2f5ffb69))

### Notable changes

*   When calling the dynamic fixture accessor method with no arguments, it now
    returns all fixtures of this type. Previously this method always returned
    an empty array.
    ([Pull Request](https://github.com/rails/rails/pull/28692))

*   Fix inconsistency with changed attributes when overriding
    Active Record attribute reader.
    ([Pull Request](https://github.com/rails/rails/pull/28661))

*   Support Descending Indexes for MySQL.
    ([Pull Request](https://github.com/rails/rails/pull/28773))

*   Fix `bin/rails db:forward` first migration.
    ([Commit](https://github.com/rails/rails/commit/b77d2aa0c336492ba33cbfade4964ba0eda3ef84))

*   Raise error `UnknownMigrationVersionError` on the movement of migrations
    when the current migration does not exist.
    ([Commit](https://github.com/rails/rails/commit/bb9d6eb094f29bb94ef1f26aa44f145f17b973fe))

*   Respect `SchemaDumper.ignore_tables` in rake tasks for
    databases structure dump.
    ([Pull Request](https://github.com/rails/rails/pull/29077))

*   Add `ActiveRecord::Base#cache_version` to support recyclable cache keys via
    the new versioned entries in `ActiveSupport::Cache`. This also means that
    `ActiveRecord::Base#cache_key` will now return a stable key that
    does not include a timestamp any more.
    ([Pull Request](https://github.com/rails/rails/pull/29092))

*   Prevent creation of bind param if casted value is nil.
    ([Pull Request](https://github.com/rails/rails/pull/29282))

*   Use bulk INSERT to insert fixtures for better performance.
    ([Pull Request](https://github.com/rails/rails/pull/29504))

*   Merging two relations representing nested joins no longer transforms
    the joins of the merged relation into LEFT OUTER JOIN.
    ([Pull Request](https://github.com/rails/rails/pull/27063))

*   Fix transactions to apply state to child transactions.
    Previously, if you had a nested transaction and the outer transaction was
    rolledback, the record from the inner transaction would still be marked
    as persisted. It was fixed by applying the state of the parent
    transaction to the child transaction when the parent transaction is
    rolledback. This will correctly mark records from the inner transaction
    as not persisted.
    ([Commit](https://github.com/rails/rails/commit/0237da287eb4c507d10a0c6d94150093acc52b03))

*   Fix eager loading/preloading association with scope including joins.
    ([Pull Request](https://github.com/rails/rails/pull/29413))

*   Prevent errors raised by `sql.active_record` notification subscribers
    from being converted into `ActiveRecord::StatementInvalid` exceptions.
    ([Pull Request](https://github.com/rails/rails/pull/29692))

*   Skip query caching when working with batches of records
    (`find_each`, `find_in_batches`, `in_batches`).
    ([Commit](https://github.com/rails/rails/commit/b83852e6eed5789b23b13bac40228e87e8822b4d))

*   Change sqlite3 boolean serialization to use 1 and 0.
    SQLite natively recognizes 1 and 0 as true and false, but does not natively
    recognize 't' and 'f' as was previously serialized.
    ([Pull Request](https://github.com/rails/rails/pull/29699))

*   Values constructed using multi-parameter assignment will now use the
    post-type-cast value for rendering in single-field form inputs.
    ([Commit](https://github.com/rails/rails/commit/1519e976b224871c7f7dd476351930d5d0d7faf6))

*   `ApplicationRecord` is no longer generated when generating models. If you
    need to generate it, it can be created with `rails g application_record`.
    ([Pull Request](https://github.com/rails/rails/pull/29916))

*   `Relation#or` now accepts two relations who have different values for
    `references` only, as `references` can be implicitly called by `where`.
    ([Commit](https://github.com/rails/rails/commit/ea6139101ccaf8be03b536b1293a9f36bc12f2f7))

*   When using `Relation#or`, extract the common conditions and
    put them before the OR condition.
    ([Pull Request](https://github.com/rails/rails/pull/29950))

*   Add `binary` fixture helper method.
    ([Pull Request](https://github.com/rails/rails/pull/30073))

*   Automatically guess the inverse associations for STI.
    ([Pull Request](https://github.com/rails/rails/pull/23425))

*   Add new error class `LockWaitTimeout` which will be raised
    when lock wait timeout exceeded.
    ([Pull Request](https://github.com/rails/rails/pull/30360))

*   Update payload names for `sql.active_record` instrumentation to be
    more descriptive.
    ([Pull Request](https://github.com/rails/rails/pull/30619))

*   Use given algorithm while removing index from database.
    ([Pull Request](https://github.com/rails/rails/pull/24199))

*   Passing a `Set` to `Relation#where` now behaves the same as passing
    an array.
    ([Commit](https://github.com/rails/rails/commit/9cf7e3494f5bd34f1382c1ff4ea3d811a4972ae2))

*   PostgreSQL `tsrange` now preserves subsecond precision.
    ([Pull Request](https://github.com/rails/rails/pull/30725))

*   Raises when calling `lock!` in a dirty record.
    ([Commit](https://github.com/rails/rails/commit/63cf15877bae859ff7b4ebaf05186f3ca79c1863))

*   Fixed a bug where column orders for an index weren't written to
    `db/schema.rb` when using the SQLite adapter.
    ([Pull Request](https://github.com/rails/rails/pull/30970))

*   Fix `bin/rails db:migrate` with specified `VERSION`.
    `bin/rails db:migrate` with empty VERSION behaves as without `VERSION`.
    Check a format of `VERSION`: Allow a migration version number
    or name of a migration file. Raise error if format of `VERSION` is invalid.
    Raise error if target migration doesn't exist.
    ([Pull Request](https://github.com/rails/rails/pull/30714))

*   Add new error class `StatementTimeout` which will be raised
    when statement timeout exceeded.
    ([Pull Request](https://github.com/rails/rails/pull/31129))

*   `update_all` will now pass its values to `Type#cast` before passing them to
    `Type#serialize`. This means that `update_all(foo: 'true')` will properly
    persist a boolean.
    ([Commit](https://github.com/rails/rails/commit/68fe6b08ee72cc47263e0d2c9ff07f75c4b42761))

*   Require raw SQL fragments to be explicitly marked when used in
    relation query methods.
    ([Commit](https://github.com/rails/rails/commit/a1ee43d2170dd6adf5a9f390df2b1dde45018a48),
    [Commit](https://github.com/rails/rails/commit/e4a921a75f8702a7dbaf41e31130fe884dea93f9))

*   Add `#up_only` to database migrations for code that is only relevant when
    migrating up, e.g. populating a new column.
    ([Pull Request](https://github.com/rails/rails/pull/31082))

*   Add new error class `QueryCanceled` which will be raised
    when canceling statement due to user request.
    ([Pull Request](https://github.com/rails/rails/pull/31235))

*   Don't allow scopes to be defined which conflict with instance methods
    on `Relation`.
    ([Pull Request](https://github.com/rails/rails/pull/31179))

*   Add support for PostgreSQL operator classes to `add_index`.
    ([Pull Request](https://github.com/rails/rails/pull/19090))

*   Log database query callers.
    ([Pull Request](https://github.com/rails/rails/pull/26815),
    [Pull Request](https://github.com/rails/rails/pull/31519),
    [Pull Request](https://github.com/rails/rails/pull/31690))

*   Undefine attribute methods on descendants when resetting column information.
    ([Pull Request](https://github.com/rails/rails/pull/31475))

*   Using subselect for `delete_all` with `limit` or `offset`.
    ([Commit](https://github.com/rails/rails/commit/9e7260da1bdc0770cf4ac547120c85ab93ff3d48))

*   Fixed inconsistency with `first(n)` when used with `limit()`.
    The `first(n)` finder now respects the `limit()`, making it consistent
    with `relation.to_a.first(n)`, and also with the behavior of `last(n)`.
    ([Pull Request](https://github.com/rails/rails/pull/27597))

*   Fix nested `has_many :through` associations on unpersisted parent instances.
    ([Commit](https://github.com/rails/rails/commit/027f865fc8b262d9ba3ee51da3483e94a5489b66))

*   Take into account association conditions when deleting through records.
    ([Commit](https://github.com/rails/rails/commit/ae48c65e411e01c1045056562319666384bb1b63))

*   Don't allow destroyed object mutation after `save` or `save!` is called.
    ([Commit](https://github.com/rails/rails/commit/562dd0494a90d9d47849f052e8913f0050f3e494))

*   Fix relation merger issue with `left_outer_joins`.
    ([Pull Request](https://github.com/rails/rails/pull/27860))

*   Support for PostgreSQL foreign tables.
    ([Pull Request](https://github.com/rails/rails/pull/31549))

*   Clear the transaction state when an Active Record object is duped.
    ([Pull Request](https://github.com/rails/rails/pull/31751))

*   Fix not expanded problem when passing an Array object as argument
    to the where method using `composed_of` column.
    ([Pull Request](https://github.com/rails/rails/pull/31724))

*   Make `reflection.klass` raise if `polymorphic?` not to be misused.
    ([Commit](https://github.com/rails/rails/commit/63fc1100ce054e3e11c04a547cdb9387cd79571a))

*   Fix `#columns_for_distinct` of MySQL and PostgreSQL to make
    `ActiveRecord::FinderMethods#limited_ids_for` use correct primary key values
    even if `ORDER BY` columns include other table's primary key.
    ([Commit](https://github.com/rails/rails/commit/851618c15750979a75635530200665b543561a44))

*   Fix `dependent: :destroy` issue for has_one/belongs_to relationship where
    the parent class was getting deleted when the child was not.
    ([Commit](https://github.com/rails/rails/commit/b0fc04aa3af338d5a90608bf37248668d59fc881))

*   Idle database connections (previously just orphaned connections) are now
    periodically reaped by the connection pool reaper.
    ([Commit](https://github.com/rails/rails/pull/31221/commits/9027fafff6da932e6e64ddb828665f4b01fc8902))

Active Model
------------

Please refer to the [Changelog][active-model] for detailed changes.

### Notable changes

*   Fix methods `#keys`, `#values` in `ActiveModel::Errors`.
    Change `#keys` to only return the keys that don't have empty messages.
    Change `#values` to only return the not empty values.
    ([Pull Request](https://github.com/rails/rails/pull/28584))

*   Add method `#merge!` for `ActiveModel::Errors`.
    ([Pull Request](https://github.com/rails/rails/pull/29714))

*   Allow passing a Proc or Symbol to length validator options.
    ([Pull Request](https://github.com/rails/rails/pull/30674))

*   Execute `ConfirmationValidator` validation when `_confirmation`'s value
    is `false`.
    ([Pull Request](https://github.com/rails/rails/pull/31058))

*   Models using the attributes API with a proc default can now be marshalled.
    ([Commit](https://github.com/rails/rails/commit/0af36c62a5710e023402e37b019ad9982e69de4b))

*   Do not lose all multiple `:includes` with options in serialization.
    ([Commit](https://github.com/rails/rails/commit/853054bcc7a043eea78c97e7705a46abb603cc44))

Active Support
--------------

Please refer to the [Changelog][active-support] for detailed changes.

### Removals

*   Remove deprecated `:if` and `:unless` string filter for callbacks.
    ([Commit](https://github.com/rails/rails/commit/c792354adcbf8c966f274915c605c6713b840548))

*   Remove deprecated `halt_callback_chains_on_return_false` option.
    ([Commit](https://github.com/rails/rails/commit/19fbbebb1665e482d76cae30166b46e74ceafe29))

### Deprecations

*   Deprecate `Module#reachable?` method.
    ([Pull Request](https://github.com/rails/rails/pull/30624))

*   Deprecate `secrets.secret_token`.
    ([Commit](https://github.com/rails/rails/commit/fbcc4bfe9a211e219da5d0bb01d894fcdaef0a0e))

### Notable changes

*   Add `fetch_values` for `HashWithIndifferentAccess`.
    ([Pull Request](https://github.com/rails/rails/pull/28316))

*   Add support for `:offset` to `Time#change`.
    ([Commit](https://github.com/rails/rails/commit/851b7f866e13518d900407c78dcd6eb477afad06))

*   Add support for `:offset` and `:zone`
    to `ActiveSupport::TimeWithZone#change`.
    ([Commit](https://github.com/rails/rails/commit/851b7f866e13518d900407c78dcd6eb477afad06))

*   Pass gem name and deprecation horizon to deprecation notifications.
    ([Pull Request](https://github.com/rails/rails/pull/28800))

*   Add support for versioned cache entries. This enables the cache stores to
    recycle cache keys, greatly saving on storage in cases with frequent churn.
    Works together with the separation of `#cache_key` and `#cache_version`
    in Active Record and its use in Action Pack's fragment caching.
    ([Pull Request](https://github.com/rails/rails/pull/29092))

*   Add `ActiveSupport::CurrentAttributes` to provide a thread-isolated
    attributes singleton. Primary use case is keeping all the per-request
    attributes easily available to the whole system.
    ([Pull Request](https://github.com/rails/rails/pull/29180))

*   `#singularize` and `#pluralize` now respect uncountables for
    the specified locale.
    ([Commit](https://github.com/rails/rails/commit/352865d0f835c24daa9a2e9863dcc9dde9e5371a))

*   Add default option to `class_attribute`.
    ([Pull Request](https://github.com/rails/rails/pull/29270))

*   Add `Date#prev_occurring` and `Date#next_occurring` to return
    specified next/previous occurring day of week.
    ([Pull Request](https://github.com/rails/rails/pull/26600))

*   Add default option to module and class attribute accessors.
    ([Pull Request](https://github.com/rails/rails/pull/29294))

*   Cache: `write_multi`.
    ([Pull Request](https://github.com/rails/rails/pull/29366))

*   Default `ActiveSupport::MessageEncryptor` to use AES 256 GCM encryption.
    ([Pull Request](https://github.com/rails/rails/pull/29263))

*   Add `freeze_time` helper which freezes time to `Time.now` in tests.
    ([Pull Request](https://github.com/rails/rails/pull/29681))

*   Make the order of `Hash#reverse_merge!` consistent
    with `HashWithIndifferentAccess`.
    ([Pull Request](https://github.com/rails/rails/pull/28077))

*   Add purpose and expiry support to `ActiveSupport::MessageVerifier` and
    `ActiveSupport::MessageEncryptor`.
    ([Pull Request](https://github.com/rails/rails/pull/29892))

*   Update `String#camelize` to provide feedback when wrong option is passed.
    ([Pull Request](https://github.com/rails/rails/pull/30039))

*   `Module#delegate_missing_to` now raises `DelegationError` if target is nil,
    similar to `Module#delegate`.
    ([Pull Request](https://github.com/rails/rails/pull/30191))

*   Add `ActiveSupport::EncryptedFile` and
    `ActiveSupport::EncryptedConfiguration`.
    ([Pull Request](https://github.com/rails/rails/pull/30067))

*   Add `config/credentials.yml.enc` to store production app secrets.
    ([Pull Request](https://github.com/rails/rails/pull/30067))

*   Add key rotation support to `MessageEncryptor` and `MessageVerifier`.
    ([Pull Request](https://github.com/rails/rails/pull/29716))

*   Return an instance of `HashWithIndifferentAccess` from
    `HashWithIndifferentAccess#transform_keys`.
    ([Pull Request](https://github.com/rails/rails/pull/30728))

*   `Hash#slice` now falls back to Ruby 2.5+'s built-in definition if defined.
    ([Commit](https://github.com/rails/rails/commit/01ae39660243bc5f0a986e20f9c9bff312b1b5f8))

*   `IO#to_json` now returns the `to_s` representation, rather than
    attempting to convert to an array. This fixes a bug where `IO#to_json`
    would raise an `IOError` when called on an unreadable object.
    ([Pull Request](https://github.com/rails/rails/pull/30953))

*   Add same method signature for `Time#prev_day` and `Time#next_day`
    in accordance with `Date#prev_day`, `Date#next_day`.
    Allows pass argument for `Time#prev_day` and `Time#next_day`.
    ([Commit](https://github.com/rails/rails/commit/61ac2167eff741bffb44aec231f4ea13d004134e))

*   Add same method signature for `Time#prev_month` and `Time#next_month`
    in accordance with `Date#prev_month`, `Date#next_month`.
    Allows pass argument for `Time#prev_month` and `Time#next_month`.
    ([Commit](https://github.com/rails/rails/commit/f2c1e3a793570584d9708aaee387214bc3543530))

*   Add same method signature for `Time#prev_year` and `Time#next_year`
    in accordance with `Date#prev_year`, `Date#next_year`.
    Allows pass argument for `Time#prev_year` and `Time#next_year`.
    ([Commit](https://github.com/rails/rails/commit/ee9d81837b5eba9d5ec869ae7601d7ffce763e3e))

*   Fix acronym support in `humanize`.
    ([Commit](https://github.com/rails/rails/commit/0ddde0a8fca6a0ca3158e3329713959acd65605d))

*   Allow `Range#include?` on TWZ ranges.
    ([Pull Request](https://github.com/rails/rails/pull/31081))

*   Cache: Enable compression by default for values > 1kB.
    ([Pull Request](https://github.com/rails/rails/pull/31147))

*   Redis cache store.
    ([Pull Request](https://github.com/rails/rails/pull/31134),
    [Pull Request](https://github.com/rails/rails/pull/31866))

*   Handle `TZInfo::AmbiguousTime` errors.
    ([Pull Request](https://github.com/rails/rails/pull/31128))

*   MemCacheStore: Support expiring counters.
    ([Commit](https://github.com/rails/rails/commit/b22ee64b5b30c6d5039c292235e10b24b1057f6d))

*   Make `ActiveSupport::TimeZone.all` return only time zones that are in
    `ActiveSupport::TimeZone::MAPPING`.
    ([Pull Request](https://github.com/rails/rails/pull/31176))

*   Changed default behavior of `ActiveSupport::SecurityUtils.secure_compare`,
    to make it not leak length information even for variable length string.
    Renamed old `ActiveSupport::SecurityUtils.secure_compare` to
    `fixed_length_secure_compare`, and started raising `ArgumentError` in
    case of length mismatch of passed strings.
    ([Pull Request](https://github.com/rails/rails/pull/24510))

*   Use SHA-1 to generate non-sensitive digests, such as the ETag header.
    ([Pull Request](https://github.com/rails/rails/pull/31289),
    [Pull Request](https://github.com/rails/rails/pull/31651))

*   `assert_changes` will always assert that the expression changes,
    regardless of `from:` and `to:` argument combinations.
    ([Pull Request](https://github.com/rails/rails/pull/31011))

*   Add missing instrumentation for `read_multi`
    in `ActiveSupport::Cache::Store`.
    ([Pull Request](https://github.com/rails/rails/pull/30268))

*   Support hash as first argument in `assert_difference`.
    This allows to specify multiple numeric differences in the same assertion.
    ([Pull Request](https://github.com/rails/rails/pull/31600))

*   Caching: MemCache and Redis `read_multi` and `fetch_multi` speedup.
    Read from the local in-memory cache before consulting the backend.
    ([Commit](https://github.com/rails/rails/commit/a2b97e4ffef971607a1be8fc7909f099b6840f36))

Active Job
----------

Please refer to the [Changelog][active-job] for detailed changes.

### Notable changes

*   Allow block to be passed to `ActiveJob::Base.discard_on` to allow custom
    handling of discard jobs.
    ([Pull Request](https://github.com/rails/rails/pull/30622))

Ruby on Rails Guides
--------------------

Please refer to the [Changelog][guides] for detailed changes.

### Notable changes

*   Add
    [Threading and Code Execution in Rails](threading_and_code_execution.html)
    Guide.
    ([Pull Request](https://github.com/rails/rails/pull/27494))

*   Add [Active Storage Overview](active_storage_overview.html) Guide.
    ([Pull Request](https://github.com/rails/rails/pull/31037))

Credits
-------

See the
[full list of contributors to Rails](https://contributors.rubyonrails.org/)
for the many people who spent many hours making Rails, the stable and robust
framework it is. Kudos to all of them.

[railties]:       https://github.com/rails/rails/blob/5-2-stable/railties/CHANGELOG.md
[action-pack]:    https://github.com/rails/rails/blob/5-2-stable/actionpack/CHANGELOG.md
[action-view]:    https://github.com/rails/rails/blob/5-2-stable/actionview/CHANGELOG.md
[action-mailer]:  https://github.com/rails/rails/blob/5-2-stable/actionmailer/CHANGELOG.md
[action-cable]:   https://github.com/rails/rails/blob/5-2-stable/actioncable/CHANGELOG.md
[active-record]:  https://github.com/rails/rails/blob/5-2-stable/activerecord/CHANGELOG.md
[active-model]:   https://github.com/rails/rails/blob/5-2-stable/activemodel/CHANGELOG.md
[active-support]: https://github.com/rails/rails/blob/5-2-stable/activesupport/CHANGELOG.md
[active-job]:     https://github.com/rails/rails/blob/5-2-stable/activejob/CHANGELOG.md
[guides]:         https://github.com/rails/rails/blob/5-2-stable/guides/CHANGELOG.md
