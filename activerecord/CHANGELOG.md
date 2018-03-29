## Rails 5.1.6 (March 29, 2018) ##

*   MySQL: Support mysql2 0.5.x.

    *Aaron Stone*

*   Apply time column precision on assignment.

    PR #20317 changed the behavior of datetime columns so that when they
    have a specified precision then on assignment the value is rounded to
    that precision. This behavior is now applied to time columns as well.

    Fixes #30301.

    *Andrew White*

*   Normalize time column values for SQLite database.

    For legacy reasons, time columns in SQLite are stored as full datetimes
    because until #24542 the quoting for time columns didn't remove the date
    component. To ensure that values are consistent we now normalize the
    date component to 2001-01-01 on reading and writing.

    *Andrew White*

*   Ensure that the date component is removed when quoting times.

    PR #24542 altered the quoting for time columns so that the date component
    was removed however it only removed it when it was 2001-01-01. Now the
    date component is removed irrespective of what the date is.

    *Andrew White*

*   Fix that after commit callbacks on update does not triggered when optimistic locking is enabled.

    *Ryuta Kamizono*

*   `ActiveRecord::Persistence#touch` does not work well when optimistic locking enabled and
    `locking_column`, without default value, is null in the database.

    *bogdanvlviv*

*   Fix destroying existing object does not work well when optimistic locking enabled and
    `locking column` is null in the database.

    *bogdanvlviv*


## Rails 5.1.5 (February 14, 2018) ##

*   PostgreSQL: Allow pg-1.0 gem to be used with Active Record.

    *Lars Kanis*

*   Fix `count(:all)` with eager loading and having an order other than the driving table.

    Fixes #31783.

    *Ryuta Kamizono*

*   Use `count(:all)` in `HasManyAssociation#count_records` to prevent invalid
    SQL queries for association counting.

    *Klas Eskilson*

*   Fix to invoke callbacks when using `update_attribute`.

    *Mike Busch*

*   Fix `count(:all)` to correctly work `distinct` with custom SELECT list.

    *Ryuta Kamizono*

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

*   Query cache was unavailable when entering the `ActiveRecord::Base.cache` block
    without being connected.

    *Tsukasa Oishi*

*   Fix `bin/rails db:setup` and `bin/rails db:test:prepare` create  wrong
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


## Rails 5.1.4 (September 07, 2017) ##

*   No changes.


## Rails 5.1.4.rc1 (August 24, 2017) ##

*   Ensure `sum` honors `distinct` on `has_many :through` associations

    Fixes #16791

    *Aaron Wortham

*   Fix `COUNT(DISTINCT ...)` with `ORDER BY` and `LIMIT` to keep the existing select list.

    *Ryuta Kamizono*

*   Fix `unscoped(where: [columns])` removing the wrong bind values

    When the `where` is called on a relation after a `or`, unscoping the column of that later `where`, it removed
    bind values used by the `or` instead.

    ```
    Post.where(id: 1).or(Post.where(id: 2)).where(foo: 3).unscope(where: :foo).to_sql
    # Currently:
    #     SELECT "posts".* FROM "posts" WHERE ("posts"."id" = 2 OR "posts"."id" = 3)
    # With fix:
    #     SELECT "posts".* FROM "posts" WHERE ("posts"."id" = 1 OR "posts"."id" = 2)
    ```

    *Maxime Handfield Lapointe*

*   When a `has_one` association is destroyed by `dependent: destroy`,
    `destroyed_by_association` will now be set to the reflection, matching the
    behaviour of `has_many` associations.

    *Lisa Ugray*


## Rails 5.1.3 (August 03, 2017) ##

*   No changes.


## Rails 5.1.3.rc3 (July 31, 2017) ##

*   No changes.


## Rails 5.1.3.rc2 (July 25, 2017) ##

*   No changes.


## Rails 5.1.3.rc1 (July 19, 2017) ##

*   `Relation#joins` is no longer affected by the target model's
    `current_scope`, with the exception of `unscoped`.

    Fixes #29338.

    *Sean Griffin*

*   Previously, when building records using a `has_many :through` association,
    if the child records were deleted before the parent was saved, they would
    still be persisted. Now, if child records are deleted before the parent is saved
    on a `has_many :through` association, the child records will not be persisted.

    *Tobias Kraze*


## Rails 5.1.2 (June 26, 2017) ##

*   Restore previous behavior of collection proxies: their values can have
    methods stubbed, and they respect extension modules applied by a default
    scope.

    *Ryuta Kamizono*

*   Loading model schema from database is now thread-safe.

    Fixes #28589.

    *Vikrant Chaudhary*, *David Abdemoulaie*


## Rails 5.1.1 (May 12, 2017) ##

*   Add type caster to `RuntimeReflection#alias_name`

    Fixes #28959.

    *Jon Moss*


## Rails 5.1.0 (April 27, 2017) ##

*   Quote database name in db:create grant statement (when database_user does not have access to create the database).

    *Rune Philosof*

*   When multiple threads are sharing a database connection inside a test using
    transactional fixtures, a nested transaction will temporarily lock the
    connection to the current thread, forcing others to wait.

    Fixes #28197.

    *Matthew Draper*

*   Load only needed records on `ActiveRecord::Relation#inspect`.

    Instead of loading all records and returning only a subset of those, just
    load the records as needed.

    Fixes #25537.

    *Hendy Tanata*

*   Remove comments from structure.sql when using postgresql adapter to avoid
    version-specific parts of the file.

    Fixes #28153.

    *Ari Pollak*

*   Add `:default` option to `belongs_to`.

    Use it to specify that an association should be initialized with a particular
    record before validation. For example:

        # Before
        belongs_to :account
        before_validation -> { self.account ||= Current.account }

        # After
        belongs_to :account, default: -> { Current.account }

    *George Claghorn*

*   Deprecate `Migrator.schema_migrations_table_name`.

    *Ryuta Kamizono*

*   Fix select with block doesn't return newly built records in has_many association.

    Fixes #28348.

    *Ryuta Kamizono*

*   Check whether `Rails.application` defined before calling it

    In #27674 we changed the migration generator to generate migrations at the
    path defined in `Rails.application.config.paths` however the code checked
    for the presence of the `Rails` constant but not the `Rails.application`
    method which caused problems when using Active Record and generators outside
    of the context of a Rails application.

    Fixes #28325.

    *Andrew White*

*   Fix `deserialize` with JSON array.

    Fixes #28285.

    *Ryuta Kamizono*

*   Fix `rake db:schema:load` with subdirectories.

    *Ryuta Kamizono*

*   Fix `rake db:migrate:status` with subdirectories.

    *Ryuta Kamizono*

*   Don't share options between reference id and type columns

    When using a polymorphic reference column in a migration, sharing options
    between the two columns doesn't make sense since they are different types.
    The `reference_id` column is usually an integer and the `reference_type`
    column a string so options like `unsigned: true` will result in an invalid
    table definition.

    *Ryuta Kamizono*

*   Use `max_identifier_length` for `index_name_length` in PostgreSQL adapter.

    *Ryuta Kamizono*

*   Deprecate `supports_migrations?` on connection adapters.

    *Ryuta Kamizono*

*   Fix regression of #1969 with SELECT aliases in HAVING clause.

    *Eugene Kenny*

*   Deprecate using `#quoted_id` in quoting.

    *Ryuta Kamizono*

*   Fix `wait_timeout` to configurable for mysql2 adapter.

    Fixes #26556.

    *Ryuta Kamizono*

*   Correctly dump native timestamp types for MySQL.

    The native timestamp type in MySQL is different from datetime type.
    Internal representation of the timestamp type is UNIX time, This means
    that timestamp columns are affected by time zone.

        > SET time_zone = '+00:00';
        Query OK, 0 rows affected (0.00 sec)

        > INSERT INTO time_with_zone(ts,dt) VALUES (NOW(),NOW());
        Query OK, 1 row affected (0.02 sec)

        > SELECT * FROM time_with_zone;
        +---------------------+---------------------+
        | ts                  | dt                  |
        +---------------------+---------------------+
        | 2016-02-07 22:11:44 | 2016-02-07 22:11:44 |
        +---------------------+---------------------+
        1 row in set (0.00 sec)

        > SET time_zone = '-08:00';
        Query OK, 0 rows affected (0.00 sec)

        > SELECT * FROM time_with_zone;
        +---------------------+---------------------+
        | ts                  | dt                  |
        +---------------------+---------------------+
        | 2016-02-07 14:11:44 | 2016-02-07 22:11:44 |
        +---------------------+---------------------+
        1 row in set (0.00 sec)

    *Ryuta Kamizono*

*   All integer-like PKs are autoincrement unless they have an explicit default.

    *Matthew Draper*

*   Omit redundant `using: :btree` for schema dumping.

    *Ryuta Kamizono*

*   Deprecate passing `default` to `index_name_exists?`.

    *Ryuta Kamizono*

*   PostgreSQL: schema dumping support for interval and OID columns.

    *Ryuta Kamizono*

*   Deprecate `supports_primary_key?` on connection adapters since it's
    been long unused and unsupported.

    *Ryuta Kamizono*

*   Make `table_name=` reset current statement cache,
    so queries are not run against the previous table name.

    *namusyaka*

*   Allow `ActiveRecord::Base#as_json` to be passed a frozen Hash.

    *Isaac Betesh*

*   Fix inspection behavior when the :id column is not primary key.

    *namusyaka*

*   Deprecate locking records with unpersisted changes.

    *Marc Schütz*

*   Remove deprecated behavior that halts callbacks when the return is false.

    *Rafael Mendonça França*

*   Deprecate `ColumnDumper#migration_keys`.

    *Ryuta Kamizono*

*   Fix `association_primary_key_type` for reflections with symbol primary key.

    Fixes #27864.

    *Daniel Colson*

*   Virtual/generated column support for MySQL 5.7.5+ and MariaDB 5.2.0+.

    MySQL generated columns: https://dev.mysql.com/doc/refman/5.7/en/create-table-generated-columns.html
    MariaDB virtual columns: https://mariadb.com/kb/en/mariadb/virtual-computed-columns/

    Declare virtual columns with `t.virtual name, type: …, as: "expression"`.
    Pass `stored: true` to persist the generated value (false by default).

    Example:

        create_table :generated_columns do |t|
          t.string  :name
          t.virtual :upper_name,  type: :string,  as: "UPPER(name)"
          t.virtual :name_length, type: :integer, as: "LENGTH(name)", stored: true
          t.index :name_length  # May be indexed, too!
        end

    *Ryuta Kamizono*

*   Deprecate `initialize_schema_migrations_table` and `initialize_internal_metadata_table`.

    *Ryuta Kamizono*

*   Support foreign key creation for SQLite3.

    *Ryuta Kamizono*

*   Place generated migrations into the path set by `config.paths["db/migrate"]`.

    *Kevin Glowacz*

*   Raise `ActiveRecord::InvalidForeignKey` when a foreign key constraint fails on SQLite3.

    *Ryuta Kamizono*

*   Add the touch option to `#increment!` and `#decrement!`.

    *Hiroaki Izu*

*   Deprecate passing a class to the `class_name` because it eagerloads more classes than
    necessary and potentially creates circular dependencies.

    *Kir Shatrov*

*   Raise error when has_many through is defined before through association.

    Fixes #26834.

    *Chris Holmes*

*   Deprecate passing `name` to `indexes`.

    *Ryuta Kamizono*

*   Remove deprecated tasks: `db:test:clone`, `db:test:clone_schema`, `db:test:clone_structure`.

    *Rafel Mendonça França*

*   Compare deserialized values for `PostgreSQL::OID::Hstore` types when
    calling `ActiveRecord::Dirty#changed_in_place?`.

    Fixes #27502.

    *Jon Moss*

*   Raise `ArgumentError` when passing an `ActiveRecord::Base` instance to `.find`,
    `.exists?` and `.update`.

    *Rafael Mendonça França*

*   Respect precision option for arrays of timestamps.

    Fixes #27514.

    *Sean Griffin*

*   Optimize slow model instantiation when using STI and `store_full_sti_class = false` option.

    *Konstantin Lazarev*

*   Add `touch` option to counter cache modifying methods.

    Works when updating, resetting, incrementing and decrementing counters:

        # Touches `updated_at`/`updated_on`.
        Topic.increment_counter(:messages_count, 1, touch: true)
        Topic.decrement_counter(:messages_count, 1, touch: true)

        # Touches `last_discussed_at`.
        Topic.reset_counters(18, :messages, touch: :last_discussed_at)

        # Touches `updated_at` and `last_discussed_at`.
        Topic.update_counters(18, messages_count: 5, touch: %i( updated_at last_discussed_at ))

    Fixes #26724.

    *Jarred Trost*

*   Remove deprecated `#uniq`, `#uniq!`, and `#uniq_value`.

    *Ryuta Kamizono*

*   Remove deprecated `#insert_sql`, `#update_sql`, and `#delete_sql`.

    *Ryuta Kamizono*

*   Remove deprecated `#use_transactional_fixtures` configuration.

    *Rafael Mendonça França*

*   Remove deprecated `#raise_in_transactional_callbacks` configuration.

    *Rafael Mendonça França*

*   Remove deprecated `#load_schema_for`.

    *Rafael Mendonça França*

*   Remove deprecated conditions parameter from `#destroy_all` and `#delete_all`.

    *Rafael Mendonça França*

*   Remove deprecated support to passing arguments to `#select` when a block is provided.

    *Rafael Mendonça França*

*   Remove deprecated support to query using commas on LIMIT.

    *Rafael Mendonça França*

*   Remove deprecated support to passing a class as a value in a query.

    *Rafael Mendonça França*

*   Raise `ActiveRecord::IrreversibleOrderError` when using `last` with an irreversible
    order.

    *Rafael Mendonça França*

*   Raise when a `has_many :through` association has an ambiguous reflection name.

    *Rafael Mendonça França*

*   Raise when `ActiveRecord::Migration` is inherited from directly.

    *Rafael Mendonça França*

*   Remove deprecated `original_exception` argument in `ActiveRecord::StatementInvalid#initialize`
    and `ActiveRecord::StatementInvalid#original_exception`.

    *Rafael Mendonça França*

*   `#tables` and `#table_exists?` return only tables and not views.

    All the deprecations on those methods were removed.

    *Rafael Mendonça França*

*   Remove deprecated `name` argument from `#tables`.

    *Rafael Mendonça França*

*   Remove deprecated support to passing a column to `#quote`.

    *Rafael Mendonça França*

*   Set `:time` as a timezone aware type and remove deprecation when
    `config.active_record.time_zone_aware_types` is not explicitly set.

    *Rafael Mendonça França*

*   Remove deprecated force reload argument in singular and collection association readers.

    *Rafael Mendonça França*

*   Remove deprecated `activerecord.errors.messages.restrict_dependent_destroy.one` and
    `activerecord.errors.messages.restrict_dependent_destroy.many` i18n scopes.

    *Rafael Mendonça França*

*   Allow passing extra flags to `db:structure:load` and `db:structure:dump`

    Introduces `ActiveRecord::Tasks::DatabaseTasks.structure_(load|dump)_flags` to customize the
    eventual commands run against the database, e.g. mysqldump/pg_dump.

    *Kir Shatrov*

*   Notifications see frozen SQL string.

    Fixes #23774.

    *Richard Monette*

*   RuntimeErrors are no longer translated to `ActiveRecord::StatementInvalid`.

    *Richard Monette*

*   Change the schema cache format to use YAML instead of Marshal.

    *Kir Shatrov*

*   Support index length and order options using both string and symbol
    column names.

    Fixes #27243.

    *Ryuta Kamizono*

*   Raise `ActiveRecord::RangeError` when values that executed are out of range.

    *Ryuta Kamizono*

*   Raise `ActiveRecord::NotNullViolation` when a record cannot be inserted
    or updated because it would violate a not null constraint.

    *Ryuta Kamizono*

*   Emulate db trigger behaviour for after_commit :destroy, :update.

    Race conditions can occur when an ActiveRecord is destroyed
    twice or destroyed and updated. The callbacks should only be
    triggered once, similar to a SQL database trigger.

    *Stefan Budeanu*

*   Moved `DecimalWithoutScale`, `Text`, and `UnsignedInteger` from Active Model to Active Record.

    *Iain Beeston*

*   Fix `write_attribute` method to check whether an attribute is aliased or not, and
    use the aliased attribute name if needed.

    *Prathamesh Sonpatki*

*   Fix `read_attribute` method to check whether an attribute is aliased or not, and
    use the aliased attribute name if needed.

    Fixes #26417.

    *Prathamesh Sonpatki*

*   PostgreSQL & MySQL: Use big integer as primary key type for new tables.

    *Jon McCartie*, *Pavel Pravosud*

*   Change the type argument of `ActiveRecord::Base#attribute` to be optional.
    The default is now `ActiveRecord::Type::Value.new`, which provides no type
    casting behavior.

    *Sean Griffin*

*   Don't treat unsigned integers with zerofill as signed.

    Fixes #27125.

    *Ryuta Kamizono*

*   Fix the uniqueness validation scope with a polymorphic association.

    *Sergey Alekseev*

*   Raise `ActiveRecord::RecordNotFound` from collection `*_ids` setters
    for unknown IDs with a better error message.

    Changes the collection `*_ids` setters to cast provided IDs the data
    type of the primary key set in the association, not the model
    primary key.

    *Dominic Cleal*

*   For PostgreSQL >= 9.4 use `pgcrypto`'s `gen_random_uuid()` instead of
    `uuid-ossp`'s UUID generation function.

    *Yuji Yaginuma*, *Yaw Boakye*

*   Introduce `Model#reload_<association>` to bring back the behavior
    of `Article.category(true)` where `category` is a singular
    association.

    The force reloading of the association reader was deprecated
    in #20888. Unfortunately the suggested alternative of
    `article.reload.category` does not expose the same behavior.

    This patch adds a reader method with the prefix `reload_` for
    singular associations. This method has the same semantics as
    passing true to the association reader used to have.

    *Yves Senn*

*   Make sure eager loading `ActiveRecord::Associations` also loads
    constants defined in `ActiveRecord::Associations::Preloader`.

    *Yves Senn*

*   Allow `ActionController::Parameters`-like objects to be passed as
    values for Postgres HStore columns.

    Fixes #26904.

    *Jon Moss*

*   Added `stat` method to `ActiveRecord::ConnectionAdapters::ConnectionPool`.

    Example:

        ActiveRecord::Base.connection_pool.stat # =>
        { size: 15, connections: 1, busy: 1, dead: 0, idle: 0, waiting: 0, checkout_timeout: 5 }

    *Pavel Evstigneev*

*   Avoid `unscope(:order)` when `limit_value` is presented for `count`
    and `exists?`.

    If `limit_value` is presented, records fetching order is very important
    for performance. We should not unscope the order in the case.

    *Ryuta Kamizono*

*   Fix an Active Record `DateTime` field `NoMethodError` caused by incomplete
    datetime.

    Fixes #24195.

    *Sen Zhang*

*   Allow `slice` to take an array of methods(without the need for splatting).

    *Cohen Carlisle*

*   Improved partial writes with HABTM and has many through associations
    to fire database query only if relation has been changed.

    Fixes #19663.

    *Mehmet Emin İNAÇ*

*   Deprecate passing arguments and block at the same time to
    `ActiveRecord::QueryMethods#select`.

    *Prathamesh Sonpatki*

*   Fixed: Optimistic locking does not work well with `null` in the database.

    Fixes #26024.

    *bogdanvlviv*

*   Fixed support for case insensitive comparisons of `text` columns in
    PostgreSQL.

    *Edho Arief*

*   Serialize JSON attribute value `nil` as SQL `NULL`, not JSON `null`.

    *Trung Duc Tran*

*   Return `true` from `update_attribute` when the value of the attribute
    to be updated is unchanged.

    Fixes #26593.

    *Prathamesh Sonpatki*

*   Always store errors details information with symbols.

    When the association is autosaved we were storing the details with
    string keys. This was creating inconsistency with other details that are
    added using the `Errors#add` method. It was also inconsistent with the
    `Errors#messages` storage.

    To fix this inconsistency we are always storing with symbols. This will
    cause a small breaking change because in those cases the details could
    be accessed as strings keys but now it can not.

    Fix #26499.

    *Rafael Mendonça França*, *Marcus Vieira*

*   Calling `touch` on a model using optimistic locking will now leave the model
    in a non-dirty state with no attribute changes.

    Fixes #26496.

    *Jakob Skjerning*

*   Using a mysql2 connection after it fails to reconnect will now have an error message
    saying the connection is closed rather than an undefined method error message.

    *Dylan Thacker-Smith*

*   PostgreSQL array columns will now respect the encoding of strings contained
    in the array.

    Fixes #26326.

    *Sean Griffin*

*   Inverse association instances will now be set before `after_find` or
    `after_initialize` callbacks are run.

    Fixes #26320.

    *Sean Griffin*

*   Remove unnecessarily association load when a `belongs_to` association has already been
    loaded then the foreign key is changed directly and the record saved.

    *James Coleman*

*   Remove standardized column types/arguments spaces in schema dump.

    *Tim Petricola*

*   Avoid loading records from database when they are already loaded using
    the `pluck` method on a collection.

    Fixes #25921.

    *Ryuta Kamizono*

*   Remove text default treated as an empty string in non-strict mode for
    consistency with other types.

    Strict mode controls how MySQL handles invalid or missing values in
    data-change statements such as INSERT or UPDATE. If strict mode is not
    in effect, MySQL inserts adjusted values for invalid or missing values
    and produces warnings.

        def test_mysql_not_null_defaults_non_strict
          using_strict(false) do
            with_mysql_not_null_table do |klass|
              record = klass.new
              assert_nil record.non_null_integer
              assert_nil record.non_null_string
              assert_nil record.non_null_text
              assert_nil record.non_null_blob

              record.save!
              record.reload

              assert_equal 0,  record.non_null_integer
              assert_equal "", record.non_null_string
              assert_equal "", record.non_null_text
              assert_equal "", record.non_null_blob
            end
          end
        end

    https://dev.mysql.com/doc/refman/5.7/en/sql-mode.html#sql-mode-strict

    *Ryuta Kamizono*

*   SQLite3 migrations to add a column to an existing table can now be
    successfully rolled back when the column was given and invalid column
    type.

    Fixes #26087.

    *Travis O'Neill*

*   Deprecate `sanitize_conditions`. Use `sanitize_sql` instead.

    *Ryuta Kamizono*

*   Doing count on relations that contain LEFT OUTER JOIN Arel node no longer
    force a DISTINCT. This solves issues when using count after a left_joins.

    *Maxime Handfield Lapointe*

*   RecordNotFound raised by association.find exposes `id`, `primary_key` and
    `model` methods to be consistent with RecordNotFound raised by Record.find.

    *Michel Pigassou*

*   Hashes can once again be passed to setters of `composed_of`, if all of the
    mapping methods are methods implemented on `Hash`.

    Fixes #25978.

    *Sean Griffin*

*   Fix the SELECT statement in `#table_comment` for MySQL.

    *Takeshi Akima*

*   Virtual attributes will no longer raise when read on models loaded from the
    database.

    *Sean Griffin*

*   Support calling the method `merge` in `scope`'s lambda.

    *Yasuhiro Sugino*

*   Fixes multi-parameter attributes conversion with invalid params.

    *Hiroyuki Ishii*

*   Add newline between each migration in `structure.sql`.

    Keeps schema migration inserts as a single commit, but allows for easier
    git diffing.

    Fixes #25504.

    *Grey Baker*, *Norberto Lopes*

*   The flag `error_on_ignored_order_or_limit` has been deprecated in favor of
    the current `error_on_ignored_order`.

    *Xavier Noria*

*   Batch processing methods support `limit`:

        Post.limit(10_000).find_each do |post|
          # ...
        end

    It also works in `find_in_batches` and `in_batches`.

    *Xavier Noria*

*   Using `group` with an attribute that has a custom type will properly cast
    the hash keys after calling a calculation method like `count`.

    Fixes #25595.

    *Sean Griffin*

*   Fix the generated `#to_param` method to use `omission: ''` so that
    the resulting output is actually up to 20 characters, not
    effectively 17 to leave room for the default "...".
    Also call `#parameterize` before `#truncate` and make the
    `separator: /-/` to maximize the information included in the
    output.

    Fixes #23635.

    *Rob Biedenharn*

*   Ensure concurrent invocations of the connection reaper cannot allocate the
    same connection to two threads.

    Fixes #25585.

    *Matthew Draper*

*   Inspecting an object with an associated array of over 10 elements no longer
    truncates the array, preventing `inspect` from looping infinitely in some
    cases.

    *Kevin McPhillips*

*   Removed the unused methods `ActiveRecord::Base.connection_id` and
    `ActiveRecord::Base.connection_id=`.

    *Sean Griffin*

*   Ensure hashes can be assigned to attributes created using `composed_of`.

    Fixes #25210.

    *Sean Griffin*

*   Fix logging edge case where if an attribute was of the binary type and
    was provided as a Hash.

    *Jon Moss*

*   Handle JSON deserialization correctly if the column default from database
    adapter returns `''` instead of `nil`.

    *Johannes Opper*

*   Introduce new Active Record transaction error classes for catching
    transaction serialization failures or deadlocks.

    *Erol Fornoles*

*   PostgreSQL: Fix `db:structure:load` silent failure on SQL error.

    The command line flag `-v ON_ERROR_STOP=1` should be used
    when invoking `psql` to make sure errors are not suppressed.

    Example:

        psql -v ON_ERROR_STOP=1 -q -f awesome-file.sql my-app-db

    Fixes #23818.

    *Ralin Chimev*


Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activerecord/CHANGELOG.md) for previous changes.
