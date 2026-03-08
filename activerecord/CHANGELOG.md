*   Avoid issuing a `ROLLBACK` statement following `TransactionRollbackError` during `COMMIT`.

    This prevents the unnecessary "WARNING: there is no transaction in progress" log spilled to stderr directly from libpq.

    *Sorah Fukumori*

*   Add `implicit_persistence_transaction` hook for customizing transaction behavior.

    A new protected method `implicit_persistence_transaction` has been added that wraps
    persistence operations (`save`, `destroy`, `touch`) in a transaction. This method can be
    overridden in models to customize transaction behavior, such as setting a specific isolation
    level or skipping transaction creation when one is already open.

    Example skipping transaction creation if one is already open:

    ```ruby
    class Account < ApplicationRecord
      private
        def implicit_persistence_transaction(connection, &block)
          if connection.transaction_open?
            yield
          else
            super
          end
        end
    end
    ```

    *Israel P Valverde*

*   Pass sql query to query log tags.

    ```ruby
    config.active_record.query_log_tags = [
      sql_length: ->(context) { context[:sql].length }
    ]
    ```

    *fatkodima*

*   Speedup `ActiveRecord::Migration.maintain_test_schema!` when using multiple databases.

    Previously, Active Record would inefficiently connect twice to each database, now it only
    connects once per database to reverify the schema.

    *Iliana Hadzhiatanasova*

*   Add `unique_by` option to `insert_all!`.

    *Chedli Bourguiba*

*   Fix PostgreSQL schema dumping to handle schema-qualified table names in foreign_key references that span different schemas.

        # before
        add_foreign_key "hst.event_log_attributes", "hst.event_logs" # emits correctly because they're in the same schema (hst)
        add_foreign_key "hst.event_log_attributes", "hst.usr.user_profiles", column: "created_by_id" # emits hst.user.* when user.* is expected

        # after
        add_foreign_key "hst.event_log_attributes", "hst.event_logs"
        add_foreign_key "hst.event_log_attributes", "usr.user_profiles", column: "created_by_id"

    *Chiperific*

*   Add `PostgreSQLAdapter.register_type_mapping` for custom SQL type registration.

    Third-party gems can now register custom type mappings without prepending
    internal methods:

        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.register_type_mapping do |type_map|
          type_map.register_type("geometry") do |oid, fmod, sql_type|
            MyGeometryType.new(sql_type)
          end
        end

    Callbacks execute in registration order.

    *Abdelkader Boudih*

*   Yield the transaction object to the block when using `with_lock`.

    *Ngan Pham*

*   Fix bug when `current_transaction.isolation` would not have been reset in test env.

    Additionally, extending the change in [#55549](https://github.com/rails/rails/pull/55549)
    to handle `requires_new: true`.

    *Kir Shatrov*

*   Allow `schema_dump` configuration to be an absolute path.

    Previously, the `schema_dump` configuration was always joined with the
    `db_dir` path. Now, if an absolute path is provided, it will be used as-is.

    *Mike Dalessio*

*   Decode PostgreSQL bytea and money columns when they appear in direct
    query results.

    bytea columns are now decoded to binary-encoded Strings, and money columns
    are decoded to BigDecimal instead of String.

    ```ruby
    ActiveRecord::Base.connection
         .select_value("select '\\x48656c6c6f'::bytea").encoding #=> Encoding::BINARY

    ActiveRecord::Base.connection
         .select_value("select '12.34'::money").class #=> BigDecimal
    ```

    *Matthew Draper*

*   Add support for configuring migration strategy on a per-adapter basis.

    `migration_strategy` can now be set on individual adapter classes, overriding
    the global `ActiveRecord.migration_strategy`. This allows individual databases to
    customize migration execution logic:

    ```ruby
    class CustomPostgresStrategy < ActiveRecord::Migration::DefaultStrategy
      def drop_table(*)
        # Custom logic specific to PostgreSQL
      end
    end

    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.migration_strategy = CustomPostgresStrategy
    ```

    *Adrianna Chang*

*   Allow either explain format syntax for EXPLAIN queries.

    MySQL uses FORMAT=JSON whereas Postgres uses FORMAT JSON. We should be
    able to accept both formats as options.

    *Gannon McGibbon*

*   On MySQL parallel test database table reset to use `DELETE` instead of `TRUNCATE`.

    Truncating on MySQL is very slow even on empty or nearly empty tables.

    As a result of this change auto increment counters are now no longer reset between test
    runs on MySQL and the `SKIP_TEST_DATABASE_TRUNCATE` environment variable no longer has
    any effect.

    *Donal McBreen*

*   Fix inconsistency in PostgreSQL handling of unbounded time range types

    Use `-infinity` rather than `NULL` for the lower value of PostgreSQL time
    ranges when saving records with a Ruby range that begins with `nil`.

    ```ruby
    create_table :products do |t|
      t.tsrange :period
    end
    class Product < ActiveRecord::Base; end

    t = Time.utc(2000)

    Product.create(period: t...nil)
    Product.create(period: nil...t)
    ```

    Previously this would create two records using different values to represent
    lower-unbounded and upper-unbounded ranges.

    ```
    ["2000-01-01 00:00:00",infinity)
    (NULL,"2000-01-01 00:00:00")
    ```

    Now both will use `-infinity`/`infinity` which are handled differently than
    `NULL` by some PostgreSQL range operators (e.g., `lower_inf`) and support
    both exclusive and inclusive bounds.

    ```
    ["2000-01-01 00:00:00",infinity)
    [-infinity,"2000-01-01 00:00:00")
    ```

    *Martin-Alexander*

*   Database-specific shard swap prohibition

    In #43485 (v7.0.0), shard swapping prohibition was introduced as a global
    switch that applied to all databases.

    For the use case of a multi-database application, the global prohibition is
    overly broad, and so with this change the method `prohibit_shard_swapping`
    will scope the prohibition to the same connection class (i.e.,
    `connection_specification_name`). This allows an application to prohibit
    shard swapping on a specific database while allowing it on all others.

    *Mike Dalessio*

*   Fix upsert_all when using repeated timestamp attributes.

    *Gannon McGibbon*

*   PostgreSQL enable drop database FORCE option.

    One of the benefits of developing with MySQL is that it allows dropping the
    current database without first disconnecting clients. As a result developers
    can use `bin/rails db:reset` and similar, without first shutting down
    instances of the app, Rails consoles, background workers, etc. By default
    PostgreSQL fails to drop a database when clients are connected and displays
    the following error:

      > PG::ObjectInUse: ERROR:  database "xyz" is being accessed by other users (PG::ObjectInUse)

    This is frustrating when working in development where the database may be
    dropped frequently.

    PostgreSQL 13 added the `FORCE` option to the `DROP DATABASE` statement
    ([PostgreSQL docs](https://www.postgresql.org/docs/current/sql-dropdatabase.html))
    which automatically disconnects clients before dropping the database.
    This option is automatically enabled for supported PostgreSQL versions.

    *Steven Webb*

*   Raise specific exception when a prohibited shard change is attempted.

    The new `ShardSwapProhibitedError` exception allows applications and
    connection-related libraries to more easily recover from this specific
    scenario. Previously an `ArgumentError` was raised, so the new exception
    subclasses `ArgumentError` for backwards compatibility.

    *Mike Dalessio*

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

*   Fix negative scopes for enums to include records with `nil` values.

    *fatkodima*

*   Improve support for SQLite database URIs.

    The `db:create` and `db:drop` tasks now correctly handle SQLite database URIs, and the
    SQLite3Adapter will create the parent directory if it does not exist.

    *Mike Dalessio*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activerecord/CHANGELOG.md) for previous changes.
