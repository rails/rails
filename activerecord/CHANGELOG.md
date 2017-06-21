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
    `locking column` is null in the database.

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
