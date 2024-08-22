## Rails 7.2.1 (August 22, 2024) ##

*   Fix detection for `enum` columns with parallelized tests and PostgreSQL.

    *Rafael Mendonça França*

*   Allow to eager load nested nil associations.

    *fatkodima*

*   Fix swallowing ignore order warning when batching using `BatchEnumerator`.

    *fatkodima*

*   Fix memory bloat on the connection pool when using the Fiber `IsolatedExecutionState`.

    *Jean Boussier*

*   Restore inferred association class with the same modularized name.

    *Justin Ko*

*   Fix `ActiveRecord::Base.inspect` to properly explain how to load schema information.

    *Jean Boussier*

*   Check invalid `enum` options for the new syntax.

    The options using `_` prefix in the old syntax are invalid in the new syntax.

    *Rafael Mendonça França*

*   Fix `ActiveRecord::Encryption::EncryptedAttributeType#type` to return
    actual cast type.

    *Vasiliy Ermolovich*

*   Fix `create_table` with `:auto_increment` option for MySQL adapter.

    *fatkodima*


## Rails 7.2.0 (August 09, 2024) ##

*   Handle commas in Sqlite3 default function definitions.

    *Stephen Margheim*

*   Fixes `validates_associated` raising an exception when configured with a
    singular association and having `index_nested_attribute_errors` enabled.

    *Martin Spickermann*

*   The constant `ActiveRecord::ImmutableRelation` has been deprecated because
    we want to reserve that name for a stronger sense of "immutable relation".
    Please use `ActiveRecord::UnmodifiableRelation` instead.

    *Xavier Noria*

*   Add condensed `#inspect` for `ConnectionPool`, `AbstractAdapter`, and
    `DatabaseConfig`.

    *Hartley McGuire*

*   Fixed a memory performance issue in Active Record attribute methods definition.

    *Jean Boussier*

*   Define the new Active Support notification event `start_transaction.active_record`.

    This event is fired when database transactions or savepoints start, and
    complements `transaction.active_record`, which is emitted when they finish.

    The payload has the transaction (`:transaction`) and the connection (`:connection`).

    *Xavier Noria*

*   Fix an issue where the IDs reader method did not return expected results
    for preloaded associations in models using composite primary keys.

    *Jay Ang*

*   The payload of `sql.active_record` Active Support notifications now has the current transaction in the `:transaction` key.

    *Xavier Noria*

*   The payload of `transaction.active_record` Active Support notifications now has the transaction the event is related to in the `:transaction` key.

    *Xavier Noria*

*   Define `ActiveRecord::Transaction#uuid`, which returns a UUID for the database transaction. This may be helpful when tracing database activity. These UUIDs are generated only on demand.

    *Xavier Noria*

*   Fix inference of association model on nested models with the same demodularized name.

    E.g. with the following setup:

    ```ruby
    class Nested::Post < ApplicationRecord
      has_one :post, through: :other
    end
    ```

    Before, `#post` would infer the model as `Nested::Post`, but now it correctly infers `Post`.

    *Joshua Young*

*   PostgreSQL `Cidr#change?` detects the address prefix change.

    *Taketo Takashima*

*   Change `BatchEnumerator#destroy_all` to return the total number of affected rows.

    Previously, it always returned `nil`.

    *fatkodima*

*   Support `touch_all` in batches.

    ```ruby
    Post.in_batches.touch_all
    ```

    *fatkodima*

*   Add support for `:if_not_exists` and `:force` options to `create_schema`.

    *fatkodima*

*   Fix `index_errors` having incorrect index in association validation errors.

    *lulalala*

*   Add `index_errors: :nested_attributes_order` mode.

    This indexes the association validation errors based on the order received by nested attributes setter, and respects the `reject_if` configuration. This enables API to provide enough information to the frontend to map the validation errors back to their respective form fields.

    *lulalala*

*   Add `Rails.application.config.active_record.postgresql_adapter_decode_dates` to opt out of decoding dates automatically with the postgresql adapter. Defaults to true.

    *Joé Dupuis*

*   Association option `query_constraints` is deprecated in favor of `foreign_key`.

    *Nikita Vasilevsky*

*   Add `ENV["SKIP_TEST_DATABASE_TRUNCATE"]` flag to speed up multi-process test runs on large DBs when all tests run within default transaction.

    This cuts ~10s from the test run of HEY when run by 24 processes against the 178 tables, since ~4,000 table truncates can then be skipped.

    *DHH*

*   Added support for recursive common table expressions.

    ```ruby
    Post.with_recursive(
      post_and_replies: [
        Post.where(id: 42),
        Post.joins('JOIN post_and_replies ON posts.in_reply_to_id = post_and_replies.id'),
      ]
    )
    ```

    Generates the following SQL:

    ```sql
    WITH RECURSIVE "post_and_replies" AS (
      (SELECT "posts".* FROM "posts" WHERE "posts"."id" = 42)
      UNION ALL
      (SELECT "posts".* FROM "posts" JOIN post_and_replies ON posts.in_reply_to_id = post_and_replies.id)
    )
    SELECT "posts".* FROM "posts"
    ```

    *ClearlyClaire*

*   `validate_constraint` can be called in a `change_table` block.

    ex:
    ```ruby
    change_table :products do |t|
      t.check_constraint "price > discounted_price", name: "price_check", validate: false
      t.validate_check_constraint "price_check"
    end
    ```

    *Cody Cutrer*

*   `PostgreSQLAdapter` now decodes columns of type date to `Date` instead of string.

    Ex:
    ```ruby
    ActiveRecord::Base.connection
         .select_value("select '2024-01-01'::date").class #=> Date
    ```

    *Joé Dupuis*

*   Strict loading using `:n_plus_one_only` does not eagerly load child associations.

    With this change, child associations are no longer eagerly loaded, to
    match intended behavior and to prevent non-deterministic order issues caused
    by calling methods like `first` or `last`. As `first` and `last` don't cause
    an N+1 by themselves, calling child associations will no longer raise.
    Fixes #49473.

    Before:

    ```ruby
    person = Person.find(1)
    person.strict_loading!(mode: :n_plus_one_only)
    person.posts.first
    # SELECT * FROM posts WHERE person_id = 1; -- non-deterministic order
    person.posts.first.firm # raises ActiveRecord::StrictLoadingViolationError
    ```

    After:

    ```ruby
    person = Person.find(1)
    person.strict_loading!(mode: :n_plus_one_only)
    person.posts.first # this is 1+1, not N+1
    # SELECT * FROM posts WHERE person_id = 1 ORDER BY id LIMIT 1;
    person.posts.first.firm # no longer raises
    ```

    *Reid Lynch*

*   Allow `Sqlite3Adapter` to use `sqlite3` gem version `2.x`.

    *Mike Dalessio*

*   Allow `ActiveRecord::Base#pluck` to accept hash values.

    ```ruby
    # Before
    Post.joins(:comments).pluck("posts.id", "comments.id", "comments.body")

    # After
    Post.joins(:comments).pluck(posts: [:id], comments: [:id, :body])
    ```

    *fatkodima*

*   Raise an `ActiveRecord::ActiveRecordError` error when the MySQL database returns an invalid version string.

    *Kevin McPhillips*

*   `ActiveRecord::Base.transaction` now yields an `ActiveRecord::Transaction` object.

    This allows to register callbacks on it.

    ```ruby
    Article.transaction do |transaction|
      article.update(published: true)
      transaction.after_commit do
        PublishNotificationMailer.with(article: article).deliver_later
      end
    end
    ```

    *Jean Boussier*

*   Add `ActiveRecord::Base.current_transaction`.

    Returns the current transaction, to allow registering callbacks on it.

    ```ruby
    Article.current_transaction.after_commit do
      PublishNotificationMailer.with(article: article).deliver_later
    end
    ```

    *Jean Boussier*

*   Add `ActiveRecord.after_all_transactions_commit` callback.

    Useful for code that may run either inside or outside a transaction and needs
    to perform work after the state changes have been properly persisted.

    ```ruby
    def publish_article(article)
      article.update(published: true)
      ActiveRecord.after_all_transactions_commit do
        PublishNotificationMailer.with(article: article).deliver_later
      end
    end
    ```

    In the above example, the block is either executed immediately if called outside
    of a transaction, or called after the open transaction is committed.

    If the transaction is rolled back, the block isn't called.

    *Jean Boussier*

*   Add the ability to ignore counter cache columns until they are backfilled.

    Starting to use counter caches on existing large tables can be troublesome, because the column
    values must be backfilled separately of the column addition (to not lock the table for too long)
    and before the use of `:counter_cache` (otherwise methods like `size`/`any?`/etc, which use
    counter caches internally, can produce incorrect results). People usually use database triggers
    or callbacks on child associations while backfilling before introducing a counter cache
    configuration to the association.

    Now, to safely backfill the column, while keeping the column updated with child records added/removed, use:

    ```ruby
    class Comment < ApplicationRecord
      belongs_to :post, counter_cache: { active: false }
    end
    ```

    While the counter cache is not "active", the methods like `size`/`any?`/etc will not use it,
    but get the results directly from the database. After the counter cache column is backfilled, simply
    remove the `{ active: false }` part from the counter cache definition, and it will now be used by the
    mentioned methods.

    *fatkodima*

*   Retry known idempotent SELECT queries on connection-related exceptions.

    SELECT queries we construct by walking the Arel tree and / or with known model attributes
    are idempotent and can safely be retried in the case of a connection error. Previously,
    adapters such as `TrilogyAdapter` would raise `ActiveRecord::ConnectionFailed: Trilogy::EOFError`
    when encountering a connection error mid-request.

    *Adrianna Chang*

*   Allow association's `foreign_key` to be composite.

    `query_constraints` option was the only way to configure a composite foreign key by passing an `Array`.
    Now it's possible to pass an Array value as `foreign_key` to achieve the same behavior of an association.

    *Nikita Vasilevsky*

*   Allow association's `primary_key` to be composite.

    Association's `primary_key` can be composite when derived from associated model `primary_key` or `query_constraints`.
    Now it's possible to explicitly set it as composite on the association.

    *Nikita Vasilevsky*

*   Add `config.active_record.permanent_connection_checkout` setting.

    Controls whether `ActiveRecord::Base.connection` raises an error, emits a deprecation warning, or neither.

    `ActiveRecord::Base.connection` checkouts a database connection from the pool and keeps it leased until the end of
    the request or job. This behavior can be undesirable in environments that use many more threads or fibers than there
    is available connections.

    This configuration can be used to track down and eliminate code that calls `ActiveRecord::Base.connection` and
    migrate it to use `ActiveRecord::Base.with_connection` instead.

    The default behavior remains unchanged, and there is currently no plans to change the default.

    *Jean Boussier*

*   Add dirties option to uncached.

    This adds a `dirties` option to `ActiveRecord::Base.uncached` and
    `ActiveRecord::ConnectionAdapters::ConnectionPool#uncached`.

    When set to `true` (the default), writes will clear all query caches belonging to the current thread.
    When set to `false`, writes to the affected connection pool will not clear any query cache.

    This is needed by Solid Cache so that cache writes do not clear query caches.

    *Donal McBreen*

*   Deprecate `ActiveRecord::Base.connection` in favor of `.lease_connection`.

    The method has been renamed as `lease_connection` to better reflect that the returned
    connection will be held for the duration of the request or job.

    This deprecation is a soft deprecation, no warnings will be issued and there is no
    current plan to remove the method.

    *Jean Boussier*

*   Deprecate `ActiveRecord::ConnectionAdapters::ConnectionPool#connection`.

    The method has been renamed as `lease_connection` to better reflect that the returned
    connection will be held for the duration of the request or job.

    *Jean Boussier*

*   Expose a generic fixture accessor for fixture names that may conflict with Minitest.

    ```ruby
    assert_equal "Ruby on Rails", web_sites(:rubyonrails).name
    assert_equal "Ruby on Rails", fixture(:web_sites, :rubyonrails).name
    ```

    *Jean Boussier*

*   Using `Model.query_constraints` with a single non-primary-key column used to raise as expected, but with an
    incorrect error message.

    This has been fixed to raise with a more appropriate error message.

    *Joshua Young*

*   Fix `has_one` association autosave setting the foreign key attribute when it is unchanged.

    This behavior is also inconsistent with autosaving `belongs_to` and can have unintended side effects like raising
    an `ActiveRecord::ReadonlyAttributeError` when the foreign key attribute is marked as read-only.

    *Joshua Young*

*   Remove deprecated behavior that would rollback a transaction block when exited using `return`, `break` or `throw`.

    *Rafael Mendonça França*

*   Deprecate `Rails.application.config.active_record.commit_transaction_on_non_local_return`.

    *Rafael Mendonça França*

*   Remove deprecated support to pass `rewhere` to `ActiveRecord::Relation#merge`.

    *Rafael Mendonça França*

*   Remove deprecated support to pass `deferrable: true` to `add_foreign_key`.

    *Rafael Mendonça França*

*   Remove deprecated support to quote `ActiveSupport::Duration`.

    *Rafael Mendonça França*

*   Remove deprecated `#quote_bound_value`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::ConnectionAdapters::ConnectionPool#connection_klass`.

    *Rafael Mendonça França*

*   Remove deprecated support to apply `#connection_pool_list`, `#active_connections?`, `#clear_active_connections!`,
    `#clear_reloadable_connections!`, `#clear_all_connections!` and `#flush_idle_connections!` to the connections pools
    for the current role when the `role` argument isn't provided.

    *Rafael Mendonça França*

*   Remove deprecated `#all_connection_pools`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::ConnectionAdapters::SchemaCache#data_sources`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::ConnectionAdapters::SchemaCache.load_from`.

    *Rafael Mendonça França*

*   Remove deprecated `#all_foreign_keys_valid?` from database adapters.

    *Rafael Mendonça França*

*   Remove deprecated support to passing coder and class as second argument to `serialize`.

    *Rafael Mendonça França*

*   Remove deprecated support to `ActiveRecord::Base#read_attribute(:id)` to return the custom primary key value.

    *Rafael Mendonça França*

*   Remove deprecated `TestFixtures.fixture_path`.

    *Rafael Mendonça França*

*   Remove deprecated behavior to support referring to a singular association by its plural name.

    *Rafael Mendonça França*

*   Deprecate `Rails.application.config.active_record.allow_deprecated_singular_associations_name`.

    *Rafael Mendonça França*

*   Remove deprecated support to passing `SchemaMigration` and `InternalMetadata` classes as arguments to
    `ActiveRecord::MigrationContext`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Migration.check_pending!` method.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::LogSubscriber.runtime` method.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::LogSubscriber.runtime=` method.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::LogSubscriber.reset_runtime` method.

    *Rafael Mendonça França*

*   Remove deprecated support to define `explain` in the connection adapter with 2 arguments.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::ActiveJobRequiredError`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Base.clear_active_connections!`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Base.clear_reloadable_connections!`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Base.clear_all_connections!`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Base.flush_idle_connections!`.

    *Rafael Mendonça França*

*   Remove deprecated `name` argument from `ActiveRecord::Base.remove_connection`.

    *Rafael Mendonça França*

*   Remove deprecated support to call `alias_attribute` with non-existent attribute names.

    *Rafael Mendonça França*

*   Remove deprecated `Rails.application.config.active_record.suppress_multiple_database_warning`.

    *Rafael Mendonça França*

*   Add `ActiveRecord::Encryption::MessagePackMessageSerializer`.

    Serialize data to the MessagePack format, for efficient storage in binary columns.

    The binary encoding requires around 30% less space than the base64 encoding
    used by the default serializer.

    *Donal McBreen*

*   Add support for encrypting binary columns.

    Ensure encryption and decryption pass `Type::Binary::Data` around for binary data.

    Previously encrypting binary columns with the `ActiveRecord::Encryption::MessageSerializer`
    incidentally worked for MySQL and SQLite, but not PostgreSQL.

    *Donal McBreen*

*   Deprecated `ENV["SCHEMA_CACHE"]` in favor of `schema_cache_path` in the database configuration.

    *Rafael Mendonça França*

*   Add `ActiveRecord::Base.with_connection` as a shortcut for leasing a connection for a short duration.

    The leased connection is yielded, and for the duration of the block, any call to `ActiveRecord::Base.connection`
    will yield that same connection.

    This is useful to perform a few database operations without causing a connection to be leased for the
    entire duration of the request or job.

    *Jean Boussier*

*   Deprecate `config.active_record.warn_on_records_fetched_greater_than` now that `sql.active_record`
    notification includes `:row_count` field.

    *Jason Nochlin*

*   The fix ensures that the association is joined using the appropriate join type
    (either inner join or left outer join) based on the existing joins in the scope.

    This prevents unintentional overrides of existing join types and ensures consistency in the generated SQL queries.

    Example:



    ```ruby
    # `associated` will use `LEFT JOIN` instead of using `JOIN`
    Post.left_joins(:author).where.associated(:author)
    ```

    *Saleh Alhaddad*

*   Fix an issue where `ActiveRecord::Encryption` configurations are not ready before the loading
    of Active Record models, when an application is eager loaded. As a result, encrypted attributes
    could be misconfigured in some cases.

    *Maxime Réty*

*   Deprecate defining an `enum` with keyword arguments.

    ```ruby
    class Function > ApplicationRecord
      # BAD
      enum color: [:red, :blue],
           type: [:instance, :class]

      # GOOD
      enum :color, [:red, :blue]
      enum :type, [:instance, :class]
    end
    ```

    *Hartley McGuire*

*   Add `config.active_record.validate_migration_timestamps` option for validating migration timestamps.

    When set, validates that the timestamp prefix for a migration is no more than a day ahead of
    the timestamp associated with the current time. This is designed to prevent migrations prefixes
    from being hand-edited to future timestamps, which impacts migration generation and other
    migration commands.

    *Adrianna Chang*

*   Properly synchronize `Mysql2Adapter#active?` and `TrilogyAdapter#active?`.

    As well as `disconnect!` and `verify!`.

    This generally isn't a big problem as connections must not be shared between
    threads, but is required when running transactional tests or system tests
    and could lead to a SEGV.

    *Jean Boussier*

*   Support `:source_location` tag option for query log tags.

    ```ruby
    config.active_record.query_log_tags << :source_location
    ```

    Calculating the caller location is a costly operation and should be used primarily in development
    (note, there is also a `config.active_record.verbose_query_logs` that serves the same purpose)
    or occasionally on production for debugging purposes.

    *fatkodima*

*   Add an option to `ActiveRecord::Encryption::Encryptor` to disable compression.

    Allow compression to be disabled by setting `compress: false`

    ```ruby
      class User
        encrypts :name, encryptor: ActiveRecord::Encryption::Encryptor.new(compress: false)
      end
    ```

    *Donal McBreen*

*   Deprecate passing strings to `ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename`.

    A `ActiveRecord::DatabaseConfigurations::DatabaseConfig` object should be passed instead.

    *Rafael Mendonça França*

*   Add `row_count` field to `sql.active_record` notification.

    This field returns the amount of rows returned by the query that emitted the notification.

    This metric is useful in cases where one wants to detect queries with big result sets.

    *Marvin Bitterlich*

*   Consistently raise an `ArgumentError` when passing an invalid argument to a nested attributes association writer.

    Previously, this would only raise on collection associations and produce a generic error on singular associations.

    Now, it will raise on both collection and singular associations.

    *Joshua Young*

*   Fix single quote escapes on default generated MySQL columns.

    MySQL 5.7.5+ supports generated columns, which can be used to create a column that is computed from an expression.

    Previously, the schema dump would output a string with double escapes for generated columns with single quotes in the default expression.

    This would result in issues when importing the schema on a fresh instance of a MySQL database.

    Now, the string will not be escaped and will be valid Ruby upon importing of the schema.

    *Yash Kapadia*

*   Fix Migrations with versions older than 7.1 validating options given to
    `add_reference` and `t.references`.

    *Hartley McGuire*

*   Add `<role>_types` class method to `ActiveRecord::DelegatedType` so that the delegated types can be introspected.

    *JP Rosevear*

*   Make `schema_dump`, `query_cache`, `replica` and `database_tasks` configurable via `DATABASE_URL`.

    This wouldn't always work previously because boolean values would be interpreted as strings.

    e.g. `DATABASE_URL=postgres://localhost/foo?schema_dump=false` now properly disable dumping the schema
    cache.

    *Mike Coutermarsh*, *Jean Boussier*

*   Introduce `ActiveRecord::Transactions::ClassMethods#set_callback`.

     It is identical to `ActiveSupport::Callbacks::ClassMethods#set_callback`
     but with support for `after_commit` and `after_rollback` callback options.

    *Joshua Young*

*   Make `ActiveRecord::Encryption::Encryptor` agnostic of the serialization format used for encrypted data.

    Previously, the encryptor instance only allowed an encrypted value serialized as a `String` to be passed to the message serializer.

    Now, the encryptor lets the configured `message_serializer` decide which types of serialized encrypted values are supported. A custom serialiser is therefore allowed to serialize `ActiveRecord::Encryption::Message` objects using a type other than `String`.

    The default `ActiveRecord::Encryption::MessageSerializer` already ensures that only `String` objects are passed for deserialization.

    *Maxime Réty*

*   Fix `encrypted_attribute?` to take into account context properties passed to `encrypts`.

    *Maxime Réty*

*   The object returned by `explain` now responds to `pluck`, `first`,
    `last`, `average`, `count`, `maximum`, `minimum`, and `sum`. Those
    new methods run `EXPLAIN` on the corresponding queries:

    ```ruby
    User.all.explain.count
    # EXPLAIN SELECT COUNT(*) FROM `users`
    # ...

    User.all.explain.maximum(:id)
    # EXPLAIN SELECT MAX(`users`.`id`) FROM `users`
    # ...
    ```

    *Petrik de Heus*

*   Fixes an issue where `validates_associated` `:on`  option wasn't respected
    when validating associated records.

    *Austen Madden*, *Alex Ghiculescu*, *Rafał Brize*

*   Allow overriding SQLite defaults from `database.yml`.

    Any PRAGMA configuration set under the `pragmas` key in the configuration
    file takes precedence over Rails' defaults, and additional PRAGMAs can be
    set as well.

    ```yaml
    database: storage/development.sqlite3
    timeout: 5000
    pragmas:
      journal_mode: off
      temp_store: memory
    ```

    *Stephen Margheim*

*   Remove warning message when running SQLite in production, but leave it unconfigured.

    There are valid use cases for running SQLite in production. However, it must be done
    with care, so instead of a warning most users won't see anyway, it's preferable to
    leave the configuration commented out to force them to think about having the database
    on a persistent volume etc.

    *Jacopo Beschi*, *Jean Boussier*

*   Add support for generated columns to the SQLite3 adapter.

    Generated columns (both stored and dynamic) are supported since version 3.31.0 of SQLite.
    This adds support for those to the SQLite3 adapter.

    ```ruby
    create_table :users do |t|
      t.string :name
      t.virtual :name_upper, type: :string, as: 'UPPER(name)'
      t.virtual :name_lower, type: :string, as: 'LOWER(name)', stored: true
    end
    ```

    *Stephen Margheim*

*   TrilogyAdapter: ignore `host` if `socket` parameter is set.

    This allows to configure a connection on a UNIX socket via `DATABASE_URL`:

    ```
    DATABASE_URL=trilogy://does-not-matter/my_db_production?socket=/var/run/mysql.sock
    ```

    *Jean Boussier*

*   Make `assert_queries_count`, `assert_no_queries`, `assert_queries_match`, and
    `assert_no_queries_match` assertions public.

    To assert the expected number of queries are made, Rails internally uses `assert_queries_count` and
    `assert_no_queries`. To assert that specific SQL queries are made, `assert_queries_match` and
    `assert_no_queries_match` are used. These assertions can now be used in applications as well.

    ```ruby
    class ArticleTest < ActiveSupport::TestCase
      test "queries are made" do
        assert_queries_count(1) { Article.first }
      end

      test "creates a foreign key" do
        assert_queries_match(/ADD FOREIGN KEY/i, include_schema: true) do
          @connection.add_foreign_key(:comments, :posts)
        end
      end
    end
    ```

    *Petrik de Heus*, *fatkodima*

*   Fix `has_secure_token` calls the setter method on initialize.

    *Abeid Ahmed*

*   When using a `DATABASE_URL`, allow for a configuration to map the protocol in the URL to a specific database
    adapter. This allows decoupling the adapter the application chooses to use from the database connection details
    set in the deployment environment.

    ```ruby
    # ENV['DATABASE_URL'] = "mysql://localhost/example_database"
    config.active_record.protocol_adapters.mysql = "trilogy"
    # will connect to MySQL using the trilogy adapter
    ```

    *Jean Boussier*, *Kevin McPhillips*

*   In cases where MySQL returns `warning_count` greater than zero, but returns no warnings when
    the `SHOW WARNINGS` query is executed, `ActiveRecord.db_warnings_action` proc will still be
    called with a generic warning message rather than silently ignoring the warning(s).

    *Kevin McPhillips*

*   `DatabaseConfigurations#configs_for` accepts a symbol in the `name` parameter.

    *Andrew Novoselac*

*   Fix `where(field: values)` queries when `field` is a serialized attribute
    (for example, when `field` uses `ActiveRecord::Base.serialize` or is a JSON
    column).

    *João Alves*

*   Make the output of `ActiveRecord::Core#inspect` configurable.

    By default, calling `inspect` on a record will yield a formatted string including just the `id`.

    ```ruby
    Post.first.inspect #=> "#<Post id: 1>"
    ```

    The attributes to be included in the output of `inspect` can be configured with
    `ActiveRecord::Core#attributes_for_inspect`.

    ```ruby
    Post.attributes_for_inspect = [:id, :title]
    Post.first.inspect #=> "#<Post id: 1, title: "Hello, World!">"
    ```

    With `attributes_for_inspect` set to `:all`, `inspect` will list all the record's attributes.

    ```ruby
    Post.attributes_for_inspect = :all
    Post.first.inspect #=> "#<Post id: 1, title: "Hello, World!", published_at: "2023-10-23 14:28:11 +0000">"
    ```

    In `development` and `test` mode, `attributes_for_inspect` will be set to `:all` by default.

    You can also call `full_inspect` to get an inspection with all the attributes.

    The attributes in `attribute_for_inspect` will also be used for `pretty_print`.

    *Andrew Novoselac*

*   Don't mark attributes as changed when reassigned to `Float::INFINITY` or
    `-Float::INFINITY`.

    *Maicol Bentancor*

*   Support the `RETURNING` clause for MariaDB.

    *fatkodima*, *Nikolay Kondratyev*

*   The SQLite3 adapter now implements the `supports_deferrable_constraints?` contract.

    Allows foreign keys to be deferred by adding the `:deferrable` key to the `foreign_key` options.

    ```ruby
    add_reference :person, :alias, foreign_key: { deferrable: :deferred }
    add_reference :alias, :person, foreign_key: { deferrable: :deferred }
    ```

    *Stephen Margheim*

*   Add the `set_constraints` helper to PostgreSQL connections.

    ```ruby
    Post.create!(user_id: -1) # => ActiveRecord::InvalidForeignKey

    Post.transaction do
      Post.connection.set_constraints(:deferred)
      p = Post.create!(user_id: -1)
      u = User.create!
      p.user = u
      p.save!
    end
    ```

    *Cody Cutrer*

*   Include `ActiveModel::API` in `ActiveRecord::Base`.

    *Sean Doyle*

*   Ensure `#signed_id` outputs `url_safe` strings.

    *Jason Meller*

*   Add `nulls_last` and working `desc.nulls_first` for MySQL.

    *Tristan Fellows*

*   Allow for more complex hash arguments for `order` which mimics `where` in `ActiveRecord::Relation`.

    ```ruby
    Topic.includes(:posts).order(posts: { created_at: :desc })
    ```

    *Myles Boone*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/activerecord/CHANGELOG.md) for previous changes.
