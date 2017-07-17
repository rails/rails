*   Change sqlite3 boolean serialization to use 1 and 0

    SQLite natively recognizes 1 and 0 as true and false, but does not natively
    recognize 't' and 'f' as was previously serialized.

    This change in serialization requires a migration of stored boolean data
    for SQLite databases, so it's implemented behind a configuration flag
    whose default false value is deprecated.

    *Lisa Ugray*

*   Skip query caching when working with batches of records (`find_each`, `find_in_batches`,
    `in_batches`).

    Previously, records would be fetched in batches, but all records would be retained in memory
    until the end of the request or job.

    *Eugene Kenny*

*   Prevent errors raised by `sql.active_record` notification subscribers from being converted into
    `ActiveRecord::StatementInvalid` exceptions.

    *Dennis Taylor*

*   Fix eager loading/preloading association with scope including joins.

    Fixes #28324.

    *Ryuta Kamizono*

*   Fix transactions to apply state to child transactions

    Previously if you had a nested transaction and the outer transaction was rolledback the record from the
    inner transaction would still be marked as persisted.

    This change fixes that by applying the state of the parent transaction to the child transaction when the
    parent transaction is rolledback. This will correctly mark records from the inner transaction as not persisted.

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   Deprecate `set_state` method in `TransactionState`

    Deprecated the `set_state` method in favor of setting the state via specific methods. If you need to mark the
    state of the transaction you can now use `rollback!`, `commit!` or `nullify!` instead of
    `set_state(:rolledback)`, `set_state(:committed)`, or `set_state(nil)`.

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   Deprecate delegating to `arel` in `Relation`.

    *Ryuta Kamizono*

*   Fix eager loading to respect `store_full_sti_class` setting.

    *Ryuta Kamizono*

*   Query cache was unavailable when entering the `ActiveRecord::Base.cache` block
    without being connected.

    *Tsukasa Oishi*

*   Previously, when building records using a `has_many :through` association,
    if the child records were deleted before the parent was saved, they would
    still be persisted. Now, if child records are deleted before the parent is saved
    on a `has_many :through` association, the child records will not be persisted.

    *Tobias Kraze*

*   Merging two relations representing nested joins no longer transforms the joins of
    the merged relation into LEFT OUTER JOIN. Example to clarify:

    ```
    Author.joins(:posts).merge(Post.joins(:comments))
    # Before the change:
    #=> SELECT ... FROM authors INNER JOIN posts ON ... LEFT OUTER JOIN comments ON...

    # After the change:
    #=> SELECT ... FROM authors INNER JOIN posts ON ... INNER JOIN comments ON...
    ```

    TODO: Add to the Rails 5.2 upgrade guide

    *Maxime Handfield Lapointe*

*   `ActiveRecord::Persistence#touch` does not work well when optimistic locking enabled and
    `locking_column`, without default value, is null in the database.

    *bogdanvlviv*

*   Fix destroying existing object does not work well when optimistic locking enabled and
    `locking_column` is null in the database.

    *bogdanvlviv*

*   Use bulk INSERT to insert fixtures for better performance.

    *Kir Shatrov*

*   Prevent making bind param if casted value is nil.

    *Ryuta Kamizono*

*   Deprecate passing arguments and block at the same time to `count` and `sum` in `ActiveRecord::Calculations`.

    *Ryuta Kamizono*

*   Loading model schema from database is now thread-safe.

    Fixes #28589.

    *Vikrant Chaudhary*, *David Abdemoulaie*

*   Add `ActiveRecord::Base#cache_version` to support recyclable cache keys via the new versioned entries
    in `ActiveSupport::Cache`. This also means that `ActiveRecord::Base#cache_key` will now return a stable key
    that does not include a timestamp any more.

    NOTE: This feature is turned off by default, and `#cache_key` will still return cache keys with timestamps
    until you set `ActiveRecord::Base.cache_versioning = true`. That's the setting for all new apps on Rails 5.2+

    *DHH*

*   Respect `SchemaDumper.ignore_tables` in rake tasks for databases structure dump

    *Rusty Geldmacher*, *Guillermo Iguaran*

*   Add type caster to `RuntimeReflection#alias_name`

    Fixes #28959.

    *Jon Moss*

*   Deprecate `supports_statement_cache?`.

    *Ryuta Kamizono*

*   Quote database name in `db:create` grant statement (when database user does not have access to create the database).

    *Rune Philosof*

*   Raise error `UnknownMigrationVersionError` on the movement of migrations
    when the current migration does not exist.

    *bogdanvlviv*

*   Fix `bin/rails db:forward` first migration.

    *bogdanvlviv*

*   Support Descending Indexes for MySQL.

    MySQL 8.0.1 and higher supports descending indexes: `DESC` in an index definition is no longer ignored.
    See https://dev.mysql.com/doc/refman/8.0/en/descending-indexes.html.

    *Ryuta Kamizono*

*   Fix inconsistency with changed attributes when overriding AR attribute reader.

    *bogdanvlviv*

*   When calling the dynamic fixture accessor method with no arguments it now returns all fixtures of this type.
    Previously this method always returned an empty array.

    *Kevin McPhillips*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/activerecord/CHANGELOG.md) for previous changes.
