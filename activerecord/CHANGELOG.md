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
