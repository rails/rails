## Rails 8.1.2 (January 08, 2026) ##

*   Fix counting cached queries in `ActiveRecord::RuntimeRegistry`.

    *fatkodima*

*   Fix merging relations with arel equality predicates with null relations.

    *fatkodima*

*   Fix SQLite3 schema dump for non-autoincrement integer primary keys.

    Previously, `schema.rb` should incorrectly restore that table with an auto incrementing
    primary key.

    *Chris Hasiński*

*   Fix PostgreSQL `schema_search_path` not being reapplied after `reset!` or `reconnect!`.

    The `schema_search_path` configured in `database.yml` is now correctly
    reapplied instead of falling back to PostgreSQL defaults.

    *Tobias Egli*

*   Restore the ability of enum to be foats.

    ```ruby
    enum :rating, { low: 0.0, medium: 0.5, high: 1.0 },
    ```

    In Rails 8.1.0, enum values are eagerly validated, and floats weren't expected.

    *Said Kaldybaev*

*   Ensure batched preloaded associations accounts for klass when grouping to avoid issues with STI.

    *zzak*, *Stjepan Hadjic*

*   Fix `ActiveRecord::SoleRecordExceeded#record` to return the relation.

    This was the case until Rails 7.2, but starting from 8.0 it
    started mistakenly returning the model class.

    *Jean Boussier*

*   Improve PostgreSQLAdapter resilience to Timeout.timeout.

    Better handle asynchronous exceptions being thrown inside
    the `reconnect!` method.

    This may fixes some deep errors such as:

    ```
    undefined method `key?' for nil:NilClass (NoMethodError)
              if !type_map.key?(oid)
    ```

    *Jean Boussier*

*   Fix structured events for Active Record was not being emitted.

    *Yuji Yaginuma*

*   Fix `eager_load` when loading `has_many` assocations with composite primary keys.

    This would result in some records being loaded multiple times.

    *Martin-Alexander*


## Rails 8.1.1 (October 28, 2025) ##

*   No changes.


## Rails 8.1.0 (October 22, 2025) ##

*   Fix SQLite3 data loss during table alterations with CASCADE foreign keys.

    When altering a table in SQLite3 that is referenced by child tables with
    `ON DELETE CASCADE` foreign keys, ActiveRecord would silently delete all
    data from the child tables. This occurred because SQLite requires table
    recreation for schema changes, and during this process the original table
    is temporarily dropped, triggering CASCADE deletes on child tables.

    The root cause was incorrect ordering of operations. The original code
    wrapped `disable_referential_integrity` inside a transaction, but
    `PRAGMA foreign_keys` cannot be modified inside a transaction in SQLite -
    attempting to do so simply has no effect. This meant foreign keys remained
    enabled during table recreation, causing CASCADE deletes to fire.

    The fix reverses the order to follow the official SQLite 12-step ALTER TABLE
    procedure: `disable_referential_integrity` now wraps the transaction instead
    of being wrapped by it. This ensures foreign keys are properly disabled
    before the transaction starts and re-enabled after it commits, preventing
    CASCADE deletes while maintaining data integrity through atomic transactions.

    *Ruy Rocha*

*   Add replicas to test database parallelization setup.

    Setup and configuration of databases for parallel testing now includes replicas.

    This fixes an issue when using a replica database, database selector middleware,
    and non-transactional tests, where integration tests running in parallel would select
    the base test database, i.e. `db_test`, instead of the numbered parallel worker database,
    i.e. `db_test_{n}`.

    *Adam Maas*

*   Support virtual (not persisted) generated columns on PostgreSQL 18+

    PostgreSQL 18 introduces virtual (not persisted) generated columns,
    which are now the default unless the `stored: true` option is explicitly specified on PostgreSQL 18+.

    ```ruby
    create_table :users do |t|
      t.string :name
      t.virtual :lower_name,  type: :string,  as: "LOWER(name)", stored: false
      t.virtual :name_length, type: :integer, as: "LENGTH(name)"
    end
    ```

    *Yasuo Honda*

*   Optimize schema dumping to prevent duplicate file generation.

    `ActiveRecord::Tasks::DatabaseTasks.dump_all` now tracks which schema files
    have already been dumped and skips dumping the same file multiple times.
    This improves performance when multiple database configurations share the
    same schema dump path.

    *Mikey Gough*, *Hartley McGuire*

*   Add structured events for Active Record:
    - `active_record.strict_loading_violation`
    - `active_record.sql`

    *Gannon McGibbon*

*   Add support for integer shard keys.
    ```ruby
    # Now accepts symbols as shard keys.
    ActiveRecord::Base.connects_to(shards: {
      1: { writing: :primary_shard_one, reading: :primary_shard_one },
      2: { writing: :primary_shard_two, reading: :primary_shard_two},
    })

    ActiveRecord::Base.connected_to(shard: 1) do
      # ..
    end
    ```

    *Nony Dutton*

*   Add `ActiveRecord::Base.only_columns`

    Similar in use case to `ignored_columns` but listing columns to consider rather than the ones
    to ignore.

    Can be useful when working with a legacy or shared database schema, or to make safe schema change
    in two deploys rather than three.

    *Anton Kandratski*

*   Use `PG::Connection#close_prepared` (protocol level Close) to deallocate
    prepared statements when available.

    To enable its use, you must have pg >= 1.6.0, libpq >= 17, and a PostgreSQL
    database version >= 17.

    *Hartley McGuire*, *Andrew Jackson*

*   Fix query cache for pinned connections in multi threaded transactional tests

    When a pinned connection is used across separate threads, they now use a separate cache store
    for each thread.

    This improve accuracy of system tests, and any test using multiple threads.

    *Heinrich Lee Yu*, *Jean Boussier*

*   Fix time attribute dirty tracking with timezone conversions.

    Time-only attributes now maintain a fixed date of 2000-01-01 during timezone conversions,
    preventing them from being incorrectly marked as changed due to date shifts.

    This fixes an issue where time attributes would be marked as changed when setting the same time value
    due to timezone conversion causing internal date shifts.

    *Prateek Choudhary*

*   Skip calling `PG::Connection#cancel` in `cancel_any_running_query`
    when using libpq >= 18 with pg < 1.6.0, due to incompatibility.
    Rollback still runs, but may take longer.

    *Yasuo Honda*, *Lars Kanis*

*   Don't add `id_value` attribute alias when attribute/column with that name already exists.

    *Rob Lewis*

*   Remove deprecated `:unsigned_float` and `:unsigned_decimal` column methods for MySQL.

    *Rafael Mendonça França*

*   Remove deprecated `:retries` option for the SQLite3 adapter.

    *Rafael Mendonça França*

*   Introduce new database configuration options `keepalive`, `max_age`, and
    `min_connections` -- and rename `pool` to `max_connections` to match.

    There are no changes to default behavior, but these allow for more specific
    control over pool behavior.

    *Matthew Draper*, *Chris AtLee*, *Rachael Wright-Munn*

*   Move `LIMIT` validation from query generation to when `limit()` is called.

    *Hartley McGuire*, *Shuyang*

*   Add `ActiveRecord::CheckViolation` error class for check constraint violations.

    *Ryuta Kamizono*

*   Add `ActiveRecord::ExclusionViolation` error class for exclusion constraint violations.

    When an exclusion constraint is violated in PostgreSQL, the error will now be raised
    as `ActiveRecord::ExclusionViolation` instead of the generic `ActiveRecord::StatementInvalid`,
    making it easier to handle these specific constraint violations in application code.

    This follows the same pattern as other constraint violation error classes like
    `RecordNotUnique` for unique constraint violations and `InvalidForeignKey` for
    foreign key constraint violations.

    *Ryuta Kamizono*

*   Attributes filtered by `filter_attributes` will now also be filtered by `filter_parameters`
    so sensitive information is not leaked.

    *Jill Klang*

*   Add `connection.current_transaction.isolation` API to check current transaction's isolation level.

    Returns the isolation level if it was explicitly set via the `isolation:` parameter
    or through `ActiveRecord.with_transaction_isolation_level`, otherwise returns `nil`.
    Nested transactions return the parent transaction's isolation level.

    ```ruby
    # Returns nil when no transaction
    User.connection.current_transaction.isolation # => nil

    # Returns explicitly set isolation level
    User.transaction(isolation: :serializable) do
      User.connection.current_transaction.isolation # => :serializable
    end

    # Returns nil when isolation not explicitly set
    User.transaction do
      User.connection.current_transaction.isolation # => nil
    end

    # Nested transactions inherit parent's isolation
    User.transaction(isolation: :read_committed) do
      User.transaction do
        User.connection.current_transaction.isolation # => :read_committed
      end
    end
    ```

    *Kir Shatrov*

*   Fix `#merge` with `#or` or `#and` and a mixture of attributes and SQL strings resulting in an incorrect query.

    ```ruby
    base = Comment.joins(:post).where(user_id: 1).where("recent = 1")
    puts base.merge(base.where(draft: true).or(Post.where(archived: true))).to_sql
    ```

    Before:

    ```SQL
    SELECT "comments".* FROM "comments"
    INNER JOIN "posts" ON "posts"."id" = "comments"."post_id"
    WHERE (recent = 1)
    AND (
      "comments"."user_id" = 1
      AND (recent = 1)
      AND "comments"."draft" = 1
      OR "posts"."archived" = 1
    )
    ```

    After:

    ```SQL
    SELECT "comments".* FROM "comments"
    INNER JOIN "posts" ON "posts"."id" = "comments"."post_id"
    WHERE "comments"."user_id" = 1
    AND (recent = 1)
    AND (
      "comments"."user_id" = 1
      AND (recent = 1)
      AND "comments"."draft" = 1
      OR "posts"."archived" = 1
    )
    ```

    *Joshua Young*

*   Make schema dumper to account for `ActiveRecord.dump_schemas` when dumping in `:ruby` format.

    *fatkodima*

*   Add `:touch` option to `update_column`/`update_columns` methods.

    ```ruby
    # Will update :updated_at/:updated_on alongside :nice column.
    user.update_column(:nice, true, touch: true)

    # Will update :updated_at/:updated_on alongside :last_ip column
    user.update_columns(last_ip: request.remote_ip, touch: true)
    ```

    *Dmitrii Ivliev*

*   Optimize Active Record batching further when using ranges.

    Tested on a PostgreSQL table with 10M records and batches of 10k records, the generation
    of relations for the 1000 batches was `4.8x` faster (`6.8s` vs. `1.4s`), used `900x`
    less bandwidth (`180MB` vs. `0.2MB`) and allocated `45x` less memory (`490MB` vs. `11MB`).

    *Maxime Réty*, *fatkodima*

*   Include current character length in error messages for index and table name length validations.

    *Joshua Young*

*   Add `rename_schema` method for PostgreSQL.

    *T S Vallender*

*   Implement support for deprecating associations:

    ```ruby
    has_many :posts, deprecated: true
    ```

    With that, Active Record will report any usage of the `posts` association.

    Three reporting modes are supported (`:warn`, `:raise`, and `:notify`), and
    backtraces can be enabled or disabled. Defaults are `:warn` mode and
    disabled backtraces.

    Please, check the docs for further details.

    *Xavier Noria*

*   PostgreSQL adapter create DB now supports `locale_provider` and `locale`.

    *Bengt-Ove Hollaender*

*   Use ntuples to populate row_count instead of count for Postgres

    *Jonathan Calvert*

*   Fix checking whether an unpersisted record is `include?`d in a strictly
    loaded `has_and_belongs_to_many` association.

    *Hartley McGuire*

*   Add ability to change transaction isolation for all pools within a block.

    This functionality is useful if your application needs to change the database
    transaction isolation for a request or action.

    Calling `ActiveRecord.with_transaction_isolation_level(level) {}` in an around filter or
    middleware will set the transaction isolation for all pools accessed within the block,
    but not for the pools that aren't.

    This works with explicit and implicit transactions:

    ```ruby
    ActiveRecord.with_transaction_isolation_level(:read_committed) do
      Tag.transaction do # opens a transaction explicitly
        Tag.create!
      end
    end
    ```

    ```ruby
    ActiveRecord.with_transaction_isolation_level(:read_committed) do
      Tag.create! # opens a transaction implicitly
    end
    ```

    *Eileen M. Uchitelle*

*   Raise `ActiveRecord::MissingRequiredOrderError` when order dependent finder methods (e.g. `#first`, `#last`) are
    called without `order` values on the relation, and the model does not have any order columns (`implicit_order_column`,
    `query_constraints`, or `primary_key`) to fall back on.

    This change will be introduced with a new framework default for Rails 8.1, and the current behavior of not raising
    an error has been deprecated with the aim of removing the configuration option in Rails 8.2.

    ```ruby
    config.active_record.raise_on_missing_required_finder_order_columns = true
    ```

    *Joshua Young*

*   `:class_name` is now invalid in polymorphic `belongs_to` associations.

    Reason is `:class_name` does not make sense in those associations because
    the class name of target records is dynamic and stored in the type column.

    Existing polymorphic associations setting this option can just delete it.
    While it did not raise, it had no effect anyway.

    *Xavier Noria*

*   Add support for multiple databases to `db:migrate:reset`.

    *Joé Dupuis*

*   Add `affected_rows` to `ActiveRecord::Result`.

    *Jenny Shen*

*   Enable passing retryable SqlLiterals to `#where`.

    *Hartley McGuire*

*   Set default for primary keys in `insert_all`/`upsert_all`.

    Previously in Postgres, updating and inserting new records in one upsert wasn't possible
    due to null primary key values. `nil` primary key values passed into `insert_all`/`upsert_all`
    are now implicitly set to the default insert value specified by adapter.

    *Jenny Shen*

*   Add a load hook `active_record_database_configurations` for `ActiveRecord::DatabaseConfigurations`

    *Mike Dalessio*

*   Use `TRUE` and `FALSE` for SQLite queries with boolean columns.

    *Hartley McGuire*

*   Bump minimum supported SQLite to 3.23.0.

    *Hartley McGuire*

*   Allow allocated Active Records to lookup associations.

    Previously, the association cache isn't setup on allocated record objects, so association
    lookups will crash. Test frameworks like mocha use allocate to check for stubbable instance
    methods, which can trigger an association lookup.

    *Gannon McGibbon*

*   Encryption now supports `support_unencrypted_data: true` being set per-attribute.

    Previously this only worked if `ActiveRecord::Encryption.config.support_unencrypted_data == true`.
    Now, if the global config is turned off, you can still opt in for a specific attribute.

    ```ruby
    # ActiveRecord::Encryption.config.support_unencrypted_data = true
    class User < ActiveRecord::Base
      encrypts :name, support_unencrypted_data: false # only supports encrypted data
      encrypts :email # supports encrypted or unencrypted data
    end
    ```

    ```ruby
    # ActiveRecord::Encryption.config.support_unencrypted_data = false
    class User < ActiveRecord::Base
      encrypts :name, support_unencrypted_data: true # supports encrypted or unencrypted data
      encrypts :email  # only supports encrypted data
    end
    ```

    *Alex Ghiculescu*

*   Model generator no longer needs a database connection to validate column types.

    *Mike Dalessio*

*   Allow signed ID verifiers to be configurable via `Rails.application.message_verifiers`

    Prior to this change, the primary way to configure signed ID verifiers was
    to set `signed_id_verifier` on each model class:

      ```ruby
      Post.signed_id_verifier = ActiveSupport::MessageVerifier.new(...)
      Comment.signed_id_verifier = ActiveSupport::MessageVerifier.new(...)
      ```

    And if the developer did not set `signed_id_verifier`, a verifier would be
    instantiated with a secret derived from `secret_key_base` and the following
    options:

      ```ruby
      { digest: "SHA256", serializer: JSON, url_safe: true }
      ```

    Thus it was cumbersome to rotate configuration for all verifiers.

    This change defines a new Rails config: [`config.active_record.use_legacy_signed_id_verifier`][].
    The default value is `:generate_and_verify`, which preserves the previous
    behavior. However, when set to `:verify`, signed ID verifiers will use
    configuration from `Rails.application.message_verifiers` (specifically,
    `Rails.application.message_verifiers["active_record/signed_id"]`) to
    generate and verify signed IDs, but will also verify signed IDs using the
    older configuration.

    To avoid complication, the new behavior only applies when `signed_id_verifier_secret`
    is not set on a model class or any of its ancestors. Additionally,
    `signed_id_verifier_secret` is now deprecated. If you are currently setting
    `signed_id_verifier_secret` on a model class, you can set `signed_id_verifier`
    instead:

      ```ruby
      # BEFORE
      Post.signed_id_verifier_secret = "my secret"

      # AFTER
      Post.signed_id_verifier = ActiveSupport::MessageVerifier.new("my secret", digest: "SHA256", serializer: JSON, url_safe: true)
      ```

    To ease migration, `signed_id_verifier` has also been changed to behave as a
    `class_attribute` (i.e. inheritable), but _only when `signed_id_verifier_secret`
    is not set_:

      ```ruby
      # BEFORE
      ActiveRecord::Base.signed_id_verifier = ActiveSupport::MessageVerifier.new(...)
      Post.signed_id_verifier == ActiveRecord::Base.signed_id_verifier # => false

      # AFTER
      ActiveRecord::Base.signed_id_verifier = ActiveSupport::MessageVerifier.new(...)
      Post.signed_id_verifier == ActiveRecord::Base.signed_id_verifier # => true

      Post.signed_id_verifier_secret = "my secret" # => deprecation warning
      Post.signed_id_verifier == ActiveRecord::Base.signed_id_verifier # => false
      ```

    Note, however, that it is recommended to eventually migrate from
    model-specific verifiers to a unified configuration managed by
    `Rails.application.message_verifiers`. `ActiveSupport::MessageVerifier#rotate`
    can facilitate that transition. For example:

      ```ruby
      # BEFORE
      # Generate and verify signed Post IDs using Post-specific configuration
      Post.signed_id_verifier = ActiveSupport::MessageVerifier.new("post secret", ...)

      # AFTER
      # Generate and verify signed Post IDs using the unified configuration
      Post.signed_id_verifier = Post.signed_id_verifier.dup
      # Fall back to Post-specific configuration when verifying signed IDs
      Post.signed_id_verifier.rotate("post secret", ...)
      ```

    [`config.active_record.use_legacy_signed_id_verifier`]: https://guides.rubyonrails.org/v8.1/configuring.html#config-active-record-use-legacy-signed-id-verifier

    *Ali Sepehri*, *Jonathan Hefner*

*   Prepend `extra_flags` in postgres' `structure_load`

    When specifying `structure_load_flags` with a postgres adapter, the flags
    were appended to the default flags, instead of prepended.
    This caused issues with flags not being taken into account by postgres.

    *Alice Loeser*

*   Allow bypassing primary key/constraint addition in `implicit_order_column`

    When specifying multiple columns in an array for `implicit_order_column`, adding
    `nil` as the last element will prevent appending the primary key to order
    conditions. This allows more precise control of indexes used by
    generated queries. It should be noted that this feature does introduce the risk
    of API misbehavior if the specified columns are not fully unique.

    *Issy Long*

*   Allow setting the `schema_format` via database configuration.

    ```
    primary:
      schema_format: ruby
    ```

    Useful for multi-database setups when apps require different formats per-database.

    *T S Vallender*

*   Support disabling indexes for MySQL v8.0.0+ and MariaDB v10.6.0+

    MySQL 8.0.0 added an option to disable indexes from being used by the query
    optimizer by making them "invisible". This allows the index to still be maintained
    and updated but no queries will be permitted to use it. This can be useful for adding
    new invisible indexes or making existing indexes invisible before dropping them
    to ensure queries are not negatively affected.
    See https://dev.mysql.com/blog-archive/mysql-8-0-invisible-indexes/ for more details.

    MariaDB 10.6.0 also added support for this feature by allowing indexes to be "ignored"
    in queries. See https://mariadb.com/kb/en/ignored-indexes/ for more details.

    Active Record now supports this option for MySQL 8.0.0+ and MariaDB 10.6.0+ for
    index creation and alteration where the new index option `enabled: true/false` can be
    passed to column and index methods as below:

    ```ruby
    add_index :users, :email, enabled: false
    enable_index :users, :email
    add_column :users, :dob, :string, index: { enabled: false }

    change_table :users do |t|
      t.index :name, enabled: false
      t.index :dob
      t.disable_index :dob
      t.column :username, :string, index: { enabled: false }
      t.references :account, index: { enabled: false }
    end

    create_table :users do |t|
      t.string :name, index: { enabled: false }
      t.string :email
      t.index :email, enabled: false
    end
    ```

    *Merve Taner*

*   Respect `implicit_order_column` in `ActiveRecord::Relation#reverse_order`.

    *Joshua Young*

*   Add column types to `ActiveRecord::Result` for SQLite3.

    *Andrew Kane*

*   Raise `ActiveRecord::ReadOnlyError` when pessimistically locking with a readonly role.

    *Joshua Young*

*   Fix using the `SQLite3Adapter`'s `dbconsole` method outside of a Rails application.

    *Hartley McGuire*

*   Fix migrating multiple databases with `ActiveRecord::PendingMigration` action.

    *Gannon McGibbon*

*   Enable automatically retrying idempotent association queries on connection
    errors.

    *Hartley McGuire*

*   Add `allow_retry` to `sql.active_record` instrumentation.

    This enables identifying queries which queries are automatically retryable on connection errors.

    *Hartley McGuire*

*   Better support UPDATE with JOIN for Postgresql and SQLite3

    Previously when generating update queries with one or more JOIN clauses,
    Active Record would use a sub query which would prevent to reference the joined
    tables in the `SET` clause, for instance:

    ```ruby
    Comment.joins(:post).update_all("title = posts.title")
    ```

    This is now supported as long as the relation doesn't also use a `LIMIT`, `ORDER` or
    `GROUP BY` clause. This was supported by the MySQL adapter for a long time.

    *Jean Boussier*

*   Introduce a before-fork hook in `ActiveSupport::Testing::Parallelization` to clear existing
    connections, to avoid fork-safety issues with the mysql2 adapter.

    Fixes #41776

    *Mike Dalessio*, *Donal McBreen*

*   PoolConfig no longer keeps a reference to the connection class.

    Keeping a reference to the class caused subtle issues when combined with reloading in
    development. Fixes #54343.

    *Mike Dalessio*

*   Fix SQL notifications sometimes not sent when using async queries.

    ```ruby
    Post.async_count
    ActiveSupport::Notifications.subscribed(->(*) { "Will never reach here" }) do
      Post.count
    end
    ```

    In rare circumstances and under the right race condition, Active Support notifications
    would no longer be dispatched after using an asynchronous query.
    This is now fixed.

    *Edouard Chin*

*   Eliminate queries loading dumped schema cache on Postgres

    Improve resiliency by avoiding needing to open a database connection to load the
    type map while defining attribute methods at boot when a schema cache file is
    configured on PostgreSQL databases.

    *James Coleman*

*   `ActiveRecord::Coder::JSON` can be instantiated

    Options can now be passed to `ActiveRecord::Coder::JSON` when instantiating the coder. This allows:
    ```ruby
    serialize :config, coder: ActiveRecord::Coder::JSON.new(symbolize_names: true)
    ```
    *matthaigh27*

*   Deprecate using `insert_all`/`upsert_all` with unpersisted records in associations.

    Using these methods on associations containing unpersisted records will now
    show a deprecation warning, as the unpersisted records will be lost after
    the operation.

    *Nick Schwaderer*

*   Make column name optional for `index_exists?`.

    This aligns well with `remove_index` signature as well, where
    index name doesn't need to be derived from the column names.

    *Ali Ismayiliov*

*   Change the payload name of `sql.active_record` notification for eager
    loading from "SQL" to "#{model.name} Eager Load".

    *zzak*

*   Enable automatically retrying idempotent `#exists?` queries on connection
    errors.

    *Hartley McGuire*, *classidied*

*   Deprecate usage of unsupported methods in conjunction with `update_all`:

    `update_all` will now print a deprecation message if a query includes either `WITH`,
    `WITH RECURSIVE` or `DISTINCT` statements. Those were never supported and were ignored
    when generating the SQL query.

    An error will be raised in a future Rails release. This behavior will be consistent
    with `delete_all` which currently raises an error for unsupported statements.

    *Edouard Chin*

*   The table columns inside `schema.rb` are now sorted alphabetically.

    Previously they'd be sorted by creation order, which can cause merge conflicts when two
    branches modify the same table concurrently.

    *John Duff*

*   Introduce versions formatter for the schema dumper.

    It is now possible to override how schema dumper formats versions information inside the
    `structure.sql` file. Currently, the versions are simply sorted in the decreasing order.
    Within large teams, this can potentially cause many merge conflicts near the top of the list.

    Now, the custom formatter can be provided with a custom sorting logic (e.g. by hash values
    of the versions), which can greatly reduce the number of conflicts.

    *fatkodima*

*   Serialized attributes can now be marked as comparable.

    A not rare issue when working with serialized attributes is that the serialized representation of an object
    can change over time. Either because you are migrating from one serializer to the other (e.g. YAML to JSON or to msgpack),
    or because the serializer used subtly changed its output.

    One example is libyaml that used to have some extra trailing whitespaces, and recently fixed that.
    When this sorts of thing happen, you end up with lots of records that report being changed even though
    they aren't, which in the best case leads to a lot more writes to the database and in the worst case lead to nasty bugs.

    The solution is to instead compare the deserialized representation of the object, however Active Record
    can't assume the deserialized object has a working `==` method. Hence why this new functionality is opt-in.

    ```ruby
    serialize :config, type: Hash, coder: JSON, comparable: true
    ```

    *Jean Boussier*

*   Fix MySQL default functions getting dropped when changing a column's nullability.

    *Bastian Bartmann*

*   SQLite extensions can be configured in `config/database.yml`.

    The database configuration option `extensions:` allows an application to load SQLite extensions
    when using `sqlite3` >= v2.4.0. The array members may be filesystem paths or the names of
    modules that respond to `.to_path`:

    ``` yaml
    development:
      adapter: sqlite3
      extensions:
        - SQLean::UUID                     # module name responding to `.to_path`
        - .sqlpkg/nalgeon/crypto/crypto.so # or a filesystem path
        - <%= AppExtensions.location %>    # or ruby code returning a path
    ```

    *Mike Dalessio*

*   `ActiveRecord::Middleware::ShardSelector` supports granular database connection switching.

    A new configuration option, `class_name:`, is introduced to
    `config.active_record.shard_selector` to allow an application to specify the abstract connection
    class to be switched by the shard selection middleware. The default class is
    `ActiveRecord::Base`.

    For example, this configuration tells `ShardSelector` to switch shards using
    `AnimalsRecord.connected_to`:

    ```
    config.active_record.shard_selector = { class_name: "AnimalsRecord" }
    ```

    *Mike Dalessio*

*   Reset relations after `insert_all`/`upsert_all`.

    Bulk insert/upsert methods will now call `reset` if used on a relation, matching the behavior of `update_all`.

    *Milo Winningham*

*   Use `_N` as a parallel tests databases suffixes

    Peviously, `-N` was used as a suffix. This can cause problems for RDBMSes
    which do not support dashes in database names.

    *fatkodima*

*   Remember when a database connection has recently been verified (for
    two seconds, by default), to avoid repeated reverifications during a
    single request.

    This should recreate a similar rate of verification as in Rails 7.1,
    where connections are leased for the duration of a request, and thus
    only verified once.

    *Matthew Draper*

*   Allow to reset cache counters for multiple records.

    ```
    Aircraft.reset_counters([1, 2, 3], :wheels_count)
    ```

    It produces much fewer queries compared to the custom implementation using looping over ids.
    Previously: `O(ids.size * counters.size)` queries, now: `O(ids.size + counters.size)` queries.

    *fatkodima*

*   Add `affected_rows` to `sql.active_record` Notification.

    *Hartley McGuire*

*   Fix `sum` when performing a grouped calculation.

    `User.group(:friendly).sum` no longer worked. This is fixed.

    *Edouard Chin*

*   Add support for enabling or disabling transactional tests per database.

    A test class can now override the default `use_transactional_tests` setting
    for individual databases, which can be useful if some databases need their
    current state to be accessible to an external process while tests are running.

    ```ruby
    class MostlyTransactionalTest < ActiveSupport::TestCase
      self.use_transactional_tests = true
      skip_transactional_tests_for_database :shared
    end
    ```

    *Matthew Cheetham*, *Morgan Mareve*

*   Cast `query_cache` value when using URL configuration.

    *zzak*

*   NULLS NOT DISTINCT works with UNIQUE CONSTRAINT as well as UNIQUE INDEX.

    *Ryuta Kamizono*

*   `PG::UnableToSend: no connection to the server` is now retryable as a connection-related exception

    *Kazuma Watanabe*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activerecord/CHANGELOG.md) for previous changes.
