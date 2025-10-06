*   Make `belongs_to` association with `optional: true` necessary when using
    inverse associations with `dependent: :nullify`.

    *francktrouillez*

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
