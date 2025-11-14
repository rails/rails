*   Allow create_join_table to accept a primary key

    Historically, `create_join_table` did not allow setting primary keys
    because it hard-coded id: false when calling the underlying `create_table`
    method. This meant that even if you passed `:primary_key` option it would be
    ignored since `id: false` took precedence and prevented any primary key
    from being added.

    The `id: false` option is no longer hard-coded but is still false by
    default, maintaining backwards compatibility. When the `:primary_key`
    option is provided, `:id` is automatically set to `:primary_key`, allowing
    primary keys to be configured. This is useful for databases like PostgreSQL
    where logical replication requires primary keys on all tables.

    ```ruby
    create_join_table :assemblies, :parts, primary_key: [:assembly_id, :part_id]
    ```

    This generates a join table with a composite primary key on both foreign key
    columns.

    *Genadi Samokovarov*

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
