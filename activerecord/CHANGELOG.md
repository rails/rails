*   Fix `dependent: :destroy` issue for has_one/belongs_to relationship where
    the parent class was getting deleted when the child was not.

    Fixes #32022.

    *Fernando Gorodscy*

*   Whitelist `NULLS FIRST` and `NULLS LAST` in order clauses too.

    *Xavier Noria*

*   Fix that after commit callbacks on update does not triggered when optimistic locking is enabled.

    *Ryuta Kamizono*

*   Fix `#columns_for_distinct` of MySQL and PostgreSQL to make
    `ActiveRecord::FinderMethods#limited_ids_for` use correct primary key values
    even if `ORDER BY` columns include other table's primary key.

    Fixes #28364.

    *Takumi Kagiyama*

*   Make `reflection.klass` raise if `polymorphic?` not to be misused.

    Fixes #31876.

    *Ryuta Kamizono*


## Rails 5.2.0.rc1 (January 30, 2018) ##

*   PostgreSQL: Allow pg-1.0 gem to be used with Active Record.

    *Lars Kanis*

*   Deprecate `expand_hash_conditions_for_aggregates` without replacement.
    Using a `Relation` for performing queries is the prefered API.

    *Ryuta Kamizono*

*   Fix not expanded problem when passing an Array object as argument to the where method using `composed_of` column.

    ```
    david_balance = customers(:david).balance
    Customer.where(balance: [david_balance]).to_sql

    # Before: WHERE `customers`.`balance` = NULL
    # After : WHERE `customers`.`balance` = 50
    ```

    Fixes #31723.

    *Yutaro Kanagawa*

*   Fix `count(:all)` with eager loading and having an order other than the driving table.

    Fixes #31783.

    *Ryuta Kamizono*

*   Clear the transaction state when an Active Record object is duped.

    Fixes #31670.

    *Yuriy Ustushenko*

*   Support for PostgreSQL foreign tables.

    *fatkodima*

*   Fix relation merger issue with `left_outer_joins`.

    *Mehmet Emin İNAÇ*

*   Don't allow destroyed object mutation after `save` or `save!` is called.

    *Ryuta Kamizono*

*   Take into account association conditions when deleting through records.

    Fixes #18424.

    *Piotr Jakubowski*

*   Fix nested `has_many :through` associations on unpersisted parent instances.

    For example, if you have

        class Post < ActiveRecord::Base
          belongs_to :author
          has_many :books, through: :author
          has_many :subscriptions, through: :books
        end

        class Author < ActiveRecord::Base
          has_one :post
          has_many :books
          has_many :subscriptions, through: :books
        end

        class Book < ActiveRecord::Base
          belongs_to :author
          has_many :subscriptions
        end

        class Subscription < ActiveRecord::Base
          belongs_to :book
        end

    Before:

    If `post` is not persisted, then `post.subscriptions` will be empty.

    After:

    If `post` is not persisted, then `post.subscriptions` can be set and used
    just like it would if `post` were persisted.

    Fixes #16313.

    *Zoltan Kiss*

*   Fixed inconsistency with `first(n)` when used with `limit()`.
    The `first(n)` finder now respects the `limit()`, making it consistent
    with `relation.to_a.first(n)`, and also with the behavior of `last(n)`.

    Fixes #23979.

    *Brian Christian*

*   Use `count(:all)` in `HasManyAssociation#count_records` to prevent invalid
    SQL queries for association counting.

    *Klas Eskilson*

*   Fix to invoke callbacks when using `update_attribute`.

    *Mike Busch*

*   Fix `count(:all)` to correctly work `distinct` with custom SELECT list.

    *Ryuta Kamizono*

*   Using subselect for `delete_all` with `limit` or `offset`.

    *Ryuta Kamizono*

*   Undefine attribute methods on descendants when resetting column
    information.

    *Chris Salzberg*

*   Log database query callers.

    Add `verbose_query_logs` configuration option to display the caller
    of database queries in the log to facilitate N+1 query resolution
    and other debugging.

    Enabled in development only for new and upgraded applications. Not
    recommended for use in the production environment since it relies
    on Ruby's `Kernel#caller_locations` which is fairly slow.

    *Olivier Lacan*

*   Fix conflicts `counter_cache` with `touch: true` by optimistic locking.

    ```
    # create_table :posts do |t|
    #   t.integer :comments_count, default: 0
    #   t.integer :lock_version
    #   t.timestamps
    # end
    class Post < ApplicationRecord
    end

    # create_table :comments do |t|
    #   t.belongs_to :post
    # end
    class Comment < ApplicationRecord
      belongs_to :post, touch: true, counter_cache: true
    end
    ```

    Before:
    ```
    post = Post.create!
    # => begin transaction
         INSERT INTO "posts" ("created_at", "updated_at", "lock_version")
         VALUES ("2017-12-11 21:27:11.387397", "2017-12-11 21:27:11.387397", 0)
         commit transaction

    comment = Comment.create!(post: post)
    # => begin transaction
         INSERT INTO "comments" ("post_id") VALUES (1)

         UPDATE "posts" SET "comments_count" = COALESCE("comments_count", 0) + 1,
         "lock_version" = COALESCE("lock_version", 0) + 1 WHERE "posts"."id" = 1

         UPDATE "posts" SET "updated_at" = '2017-12-11 21:27:11.398330',
         "lock_version" = 1 WHERE "posts"."id" = 1 AND "posts"."lock_version" = 0
         rollback transaction
    # => ActiveRecord::StaleObjectError: Attempted to touch a stale object: Post.

    Comment.take.destroy!
    # => begin transaction
         DELETE FROM "comments" WHERE "comments"."id" = 1

         UPDATE "posts" SET "comments_count" = COALESCE("comments_count", 0) - 1,
         "lock_version" = COALESCE("lock_version", 0) + 1 WHERE "posts"."id" = 1

         UPDATE "posts" SET "updated_at" = '2017-12-11 21:42:47.785901',
         "lock_version" = 1 WHERE "posts"."id" = 1 AND "posts"."lock_version" = 0
         rollback transaction
    # => ActiveRecord::StaleObjectError: Attempted to touch a stale object: Post.
    ```

    After:
    ```
    post = Post.create!
    # => begin transaction
         INSERT INTO "posts" ("created_at", "updated_at", "lock_version")
         VALUES ("2017-12-11 21:27:11.387397", "2017-12-11 21:27:11.387397", 0)
         commit transaction

    comment = Comment.create!(post: post)
    # => begin transaction
         INSERT INTO "comments" ("post_id") VALUES (1)

         UPDATE "posts" SET "comments_count" = COALESCE("comments_count", 0) + 1,
         "lock_version" = COALESCE("lock_version", 0) + 1,
         "updated_at" = '2017-12-11 21:37:09.802642' WHERE "posts"."id" = 1
         commit transaction

    comment.destroy!
    # => begin transaction
         DELETE FROM "comments" WHERE "comments"."id" = 1

         UPDATE "posts" SET "comments_count" = COALESCE("comments_count", 0) - 1,
         "lock_version" = COALESCE("lock_version", 0) + 1,
         "updated_at" = '2017-12-11 21:39:02.685520' WHERE "posts"."id" = 1
         commit transaction
    ```

    Fixes #31199.

    *bogdanvlviv*

*   Add support for PostgreSQL operator classes to `add_index`.

    Example:

        add_index :users, :name, using: :gist, opclass: { name: :gist_trgm_ops }

    *Greg Navis*

*   Don't allow scopes to be defined which conflict with instance methods on `Relation`.

    Fixes #31120.

    *kinnrot*


## Rails 5.2.0.beta2 (November 28, 2017) ##

*   No changes.


## Rails 5.2.0.beta1 (November 27, 2017) ##

*   Add new error class `QueryCanceled` which will be raised
    when canceling statement due to user request.

    *Ryuta Kamizono*

*   Add `#up_only` to database migrations for code that is only relevant when
    migrating up, e.g. populating a new column.

    *Rich Daley*

*   Require raw SQL fragments to be explicitly marked when used in
    relation query methods.

    Before:
    ```
    Article.order("LENGTH(title)")
    ```

    After:
    ```
    Article.order(Arel.sql("LENGTH(title)"))
    ```

    This prevents SQL injection if applications use the [strongly
    discouraged] form `Article.order(params[:my_order])`, under the
    mistaken belief that only column names will be accepted.

    Raw SQL strings will now cause a deprecation warning, which will
    become an UnknownAttributeReference error in Rails 6.0. Applications
    can opt in to the future behavior by setting `allow_unsafe_raw_sql`
    to `:disabled`.

    Common and judged-safe string values (such as simple column
    references) are unaffected:
    ```
    Article.order("title DESC")
    ```

    *Ben Toews*

*   `update_all` will now pass its values to `Type#cast` before passing them to
    `Type#serialize`. This means that `update_all(foo: 'true')` will properly
    persist a boolean.

    *Sean Griffin*

*   Add new error class `StatementTimeout` which will be raised
    when statement timeout exceeded.

    *Ryuta Kamizono*

*   Fix `bin/rails db:migrate` with specified `VERSION`.
    `bin/rails db:migrate` with empty VERSION behaves as without `VERSION`.
    Check a format of `VERSION`: Allow a migration version number
    or name of a migration file. Raise error if format of `VERSION` is invalid.
    Raise error if target migration doesn't exist.

    *bogdanvlviv*

*   Fixed a bug where column orders for an index weren't written to
    `db/schema.rb` when using the sqlite adapter.

    Fixes #30902.

    *Paul Kuruvilla*

*   Remove deprecated method `#sanitize_conditions`.

    *Rafael Mendonça França*

*   Remove deprecated method `#scope_chain`.

    *Rafael Mendonça França*

*   Remove deprecated configuration `.error_on_ignored_order_or_limit`.

    *Rafael Mendonça França*

*   Remove deprecated arguments from `#verify!`.

    *Rafael Mendonça França*

*   Remove deprecated argument `name` from `#indexes`.

    *Rafael Mendonça França*

*   Remove deprecated method `ActiveRecord::Migrator.schema_migrations_table_name`.

    *Rafael Mendonça França*

*   Remove deprecated method `supports_primary_key?`.

    *Rafael Mendonça França*

*   Remove deprecated method `supports_migrations?`.

    *Rafael Mendonça França*

*   Remove deprecated methods `initialize_schema_migrations_table` and `initialize_internal_metadata_table`.

    *Rafael Mendonça França*

*   Raises when calling `lock!` in a dirty record.

    *Rafael Mendonça França*

*   Remove deprecated support to passing a class to `:class_name` on associations.

    *Rafael Mendonça França*

*   Remove deprecated argument `default` from `index_name_exists?`.

    *Rafael Mendonça França*

*   Remove deprecated support to `quoted_id` when typecasting an Active Record object.

    *Rafael Mendonça França*

*   Fix `bin/rails db:setup` and `bin/rails db:test:prepare` create wrong
    ar_internal_metadata's data for a test database.

    Before:
    ```
    $ RAILS_ENV=test rails dbconsole
    > SELECT * FROM ar_internal_metadata;
    key|value|created_at|updated_at
    environment|development|2017-09-11 23:14:10.815679|2017-09-11 23:14:10.815679
    ```

    After:
    ```
    $ RAILS_ENV=test rails dbconsole
    > SELECT * FROM ar_internal_metadata;
    key|value|created_at|updated_at
    environment|test|2017-09-11 23:14:10.815679|2017-09-11 23:14:10.815679
    ```

    Fixes #26731.

    *bogdanvlviv*

*   Fix longer sequence name detection for serial columns.

    Fixes #28332.

    *Ryuta Kamizono*

*   MySQL: Don't lose `auto_increment: true` in the `db/schema.rb`.

    Fixes #30894.

    *Ryuta Kamizono*

*   Fix `COUNT(DISTINCT ...)` for `GROUP BY` with `ORDER BY` and `LIMIT`.

    Fixes #30886.

    *Ryuta Kamizono*

*   PostgreSQL `tsrange` now preserves subsecond precision.

    PostgreSQL 9.1+ introduced range types, and Rails added support for using
    this datatype in Active Record. However, the serialization of
    `PostgreSQL::OID::Range` was incomplete, because it did not properly
    cast the bounds that make up the range. This led to subseconds being
    dropped in SQL commands:

    Before:

        connection.type_cast(tsrange.serialize(range_value))
        # => "[2010-01-01 13:30:00 UTC,2011-02-02 19:30:00 UTC)"

    Now:

        connection.type_cast(tsrange.serialize(range_value))
        # => "[2010-01-01 13:30:00.670277,2011-02-02 19:30:00.745125)"

    *Thomas Cannon*

*   Passing a `Set` to `Relation#where` now behaves the same as passing an
    array.

    *Sean Griffin*

*   Use given algorithm while removing index from database.

    Fixes #24190.

    *Mehmet Emin İNAÇ*

*   Update payload names for `sql.active_record` instrumentation to be
    more descriptive.

    Fixes #30586.

    *Jeremy Green*

*   Add new error class `LockWaitTimeout` which will be raised
    when lock wait timeout exceeded.

    *Gabriel Courtemanche*

*   Remove deprecated `#migration_keys`.

    *Ryuta Kamizono*

*   Automatically guess the inverse associations for STI.

    *Yuichiro Kaneko*

*   Ensure `sum` honors `distinct` on `has_many :through` associations.

    Fixes #16791.

    *Aaron Wortham*

*   Add `binary` fixture helper method.

    *Atsushi Yoshida*

*   When using `Relation#or`, extract the common conditions and put them before the OR condition.

    *Maxime Handfield Lapointe*

*   `Relation#or` now accepts two relations who have different values for
    `references` only, as `references` can be implicitly called by `where`.

    Fixes #29411.

    *Sean Griffin*

*   `ApplicationRecord` is no longer generated when generating models. If you
    need to generate it, it can be created with `rails g application_record`.

    *Lisa Ugray*

*   Fix `COUNT(DISTINCT ...)` with `ORDER BY` and `LIMIT` to keep the existing select list.

    *Ryuta Kamizono*

*   When a `has_one` association is destroyed by `dependent: destroy`,
    `destroyed_by_association` will now be set to the reflection, matching the
    behaviour of `has_many` associations.

    *Lisa Ugray*

*   Fix `unscoped(where: [columns])` removing the wrong bind values.

    When the `where` is called on a relation after a `or`, unscoping the column of that later `where` removed
    bind values used by the `or` instead. (possibly other cases too)

    ```
    Post.where(id: 1).or(Post.where(id: 2)).where(foo: 3).unscope(where: :foo).to_sql
    # Currently:
    #     SELECT "posts".* FROM "posts" WHERE ("posts"."id" = 2 OR "posts"."id" = 3)
    # With fix:
    #     SELECT "posts".* FROM "posts" WHERE ("posts"."id" = 1 OR "posts"."id" = 2)
    ```

    *Maxime Handfield Lapointe*

*   Values constructed using multi-parameter assignment will now use the
    post-type-cast value for rendering in single-field form inputs.

    *Sean Griffin*

*   `Relation#joins` is no longer affected by the target model's
    `current_scope`, with the exception of `unscoped`.

    Fixes #29338.

    *Sean Griffin*

*   Change sqlite3 boolean serialization to use 1 and 0.

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

*   Fix transactions to apply state to child transactions.

    Previously, if you had a nested transaction and the outer transaction was rolledback, the record from the
    inner transaction would still be marked as persisted.

    This change fixes that by applying the state of the parent transaction to the child transaction when the
    parent transaction is rolledback. This will correctly mark records from the inner transaction as not persisted.

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   Deprecate `set_state` method in `TransactionState`.

    Deprecated the `set_state` method in favor of setting the state via specific methods. If you need to mark the
    state of the transaction you can now use `rollback!`, `commit!` or `nullify!` instead of
    `set_state(:rolledback)`, `set_state(:committed)`, or `set_state(nil)`.

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   Deprecate delegating to `arel` in `Relation`.

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
    the merged relation into LEFT OUTER JOIN.

    Example:

    ```
    Author.joins(:posts).merge(Post.joins(:comments))
    # Before the change:
    #=> SELECT ... FROM authors INNER JOIN posts ON ... LEFT OUTER JOIN comments ON...

    # After the change:
    #=> SELECT ... FROM authors INNER JOIN posts ON ... INNER JOIN comments ON...
    ```

    *Maxime Handfield Lapointe*

*   `ActiveRecord::Persistence#touch` does not work well when optimistic locking enabled and
    `locking_column`, without default value, is null in the database.

    *bogdanvlviv*

*   Fix destroying existing object does not work well when optimistic locking enabled and
    `locking_column` is null in the database.

    *bogdanvlviv*

*   Use bulk INSERT to insert fixtures for better performance.

    *Kir Shatrov*

*   Prevent creation of bind param if casted value is nil.

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

*   Respect `SchemaDumper.ignore_tables` in rake tasks for databases structure dump.

    *Rusty Geldmacher*, *Guillermo Iguaran*

*   Add type caster to `RuntimeReflection#alias_name`.

    Fixes #28959.

    *Jon Moss*

*   Deprecate `supports_statement_cache?`.

    *Ryuta Kamizono*

*   Raise error `UnknownMigrationVersionError` on the movement of migrations
    when the current migration does not exist.

    *bogdanvlviv*

*   Fix `bin/rails db:forward` first migration.

    *bogdanvlviv*

*   Support Descending Indexes for MySQL.

    MySQL 8.0.1 and higher supports descending indexes: `DESC` in an index definition is no longer ignored.
    See https://dev.mysql.com/doc/refman/8.0/en/descending-indexes.html.

    *Ryuta Kamizono*

*   Fix inconsistency with changed attributes when overriding Active Record attribute reader.

    *bogdanvlviv*

*   When calling the dynamic fixture accessor method with no arguments, it now returns all fixtures of this type.
    Previously this method always returned an empty array.

    *Kevin McPhillips*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/activerecord/CHANGELOG.md) for previous changes.
