## Rails 4.2.3 (June 25, 2015) ##

*   Let `WITH` queries (Common Table Expressions) be explainable.

    *Vladimir Kochnev*

*   Fix n+1 query problem when eager loading nil associations (fixes #18312)

    *Sammy Larbi*

*   Fixed an error which would occur in dirty checking when calling
    `update_attributes` from a getter.

    Fixes #20531.

    *Sean Griffin*

*   Ensure symbols passed to `ActiveRecord::Relation#select` are always treated
    as columns.

    Fixes #20360.

    *Sean Griffin*

*   Clear query cache when `ActiveRecord::Base#reload` is called.

    *Shane Hender*

*   Pass `:extend` option for `has_and_belongs_to_many` associations to the
    underlying `has_many :through`.

    *Jaehyun Shin*

*   Make `unscope` aware of "less than" and "greater than" conditions.

    *TAKAHASHI Kazuaki*

*   Revert behavior of `db:schema:load` back to loading the full
    environment. This ensures that initializers are run.

    Fixes #19545.

    *Yves Senn*

*   Fix missing index when using `timestamps` with the `index` option.

    The `index` option used with `timestamps` should be passed to both
    `column` definitions for `created_at` and `updated_at` rather than just
    the first.

    *Paul Mucur*

*   Rename `:class` to `:anonymous_class` in association options.

    Fixes #19659.

    *Andrew White*

*   Fixed a bug where uniqueness validations would error on out of range values,
    even if an validation should have prevented it from hitting the database.

    *Andrey Voronkov*

*   Foreign key related methods in the migration DSL respect
    `ActiveRecord::Base.pluralize_table_names = false`.

    Fixes #19643.

    *Mehmet Emin İNAÇ*

*   Reduce memory usage from loading types on pg.

    Fixes #19578.

    *Sean Griffin*

*   Fix referencing wrong table aliases while joining tables of has many through
    association (only when calling calculation methods).

    Fixes #19276.

    *pinglamb*

*   Don't attempt to update counter caches, when the column wasn't selected.

    Fixes #19437.

    *Sean Griffin*

*   Correctly persist a serialized attribute that has been returned to
    its default value by an in-place modification.

    Fixes #19467.

    *Matthew Draper*

*   Fix default `format` value in `ActiveRecord::Tasks::DatabaseTasks#schema_file`.

    *James Cox*

*   Dont enroll records in the transaction if they dont have commit callbacks.
    That was causing a memory grow problem when creating a lot of records inside a transaction.

    Fixes #15549.

    *Will Bryant*, *Aaron Patterson*

*   Correctly create through records when created on a has many through
    association when using `where`.

    Fixes #19073.

    *Sean Griffin*


## Rails 4.2.2 (June 16, 2015) ##

* No Changes *


## Rails 4.2.1 (March 19, 2015) ##

*   Fixed ActiveRecord::Relation#becomes! and changed_attributes issues for type column

    Fixes #17139.

    *Miklos Fazekas*

*   `remove_reference` with `foreign_key: true` removes the foreign key before
    removing the column. This fixes a bug where it was not possible to remove
    the column on MySQL.

    Fixes #18664.

    *Yves Senn*

*   Add a `:foreign_key` option to `references` and associated migration
    methods. The model and migration generators now use this option, rather than
    the `add_foreign_key` form.

    *Sean Griffin*

*   Fix rounding problem for PostgreSQL timestamp column.

    If timestamp column have the precision, it need to format according to
    the precision of timestamp column.

    *Ryuta Kamizono*

*   Respect the database default charset for `schema_migrations` table.

    The charset of `version` column in `schema_migrations` table is depend
    on the database default charset and collation rather than the encoding
    of the connection.

    *Ryuta Kamizono*

*   Respect custom primary keys for associations when calling `Relation#where`

    Fixes #18813.

    *Sean Griffin*

*   Fixed several edge cases which could result in a counter cache updating
    twice or not updating at all for `has_many` and `has_many :through`.

    Fixes #10865.

    *Sean Griffin*

*   Foreign keys added by migrations were given random, generated names. This
    meant a different `structure.sql` would be generated every time a developer
    ran migrations on their machine.

    The generated part of foreign key names is now a hash of the table name and
    column name, which is consistent every time you run the migration.

    *Chris Sinjakli*

*   Fixed ActiveRecord::Relation#group method when argument is SQL reserved key word:

      SplitTest.group(:key).count
      Property.group(:value).count

    *Bogdan Gusiev*

*   Don't define autosave association callbacks twice from
    `accepts_nested_attributes_for`.

    Fixes #18704.

    *Sean Griffin*

*   Integer types will no longer raise a `RangeError` when assigning an
    attribute, but will instead raise when going to the database.

    Fixes several vague issues which were never reported directly. See the
    commit message from the commit which added this line for some examples.

    *Sean Griffin*

*   Values which would error while being sent to the database (such as an
    ASCII-8BIT string with invalid UTF-8 bytes on Sqlite3), no longer error on
    assignment. They will still error when sent to the database, but you are
    given the ability to re-assign it to a valid value.

    Fixes #18580.

    *Sean Griffin*

*   Don't remove join dependencies in `Relation#exists?`

    Fixes #18632.

    *Sean Griffin*

*   Invalid values assigned to a JSON column are assumed to be `nil`.

    Fixes #18629.

    *Sean Griffin*

*   No longer issue deprecation warning when including a scope with extensions.
    Previously every scope with extension methods was transformed into an
    instance dependent scope. Including such a scope would wrongfully issue a
    deprecation warning. This is no longer the case.

    Fixes #18467.

    *Yves Senn*

*   Correctly use the type provided by `serialize` when updating records using
    optimistic locking.

    Fixes #18385.

    *Sean Griffin*

*   `attribute_will_change!` will no longer cause non-persistable attributes to
    be sent to the database.

    Fixes #18407.

    *Sean Griffin*

*   Format the datetime string according to the precision of the datetime field.

    Incompatible to rounding behavior between MySQL 5.6 and earlier.

    In 5.5, when you insert `2014-08-17 12:30:00.999999` the fractional part
    is ignored. In 5.6, it's rounded to `2014-08-17 12:30:01`:

    http://bugs.mysql.com/bug.php?id=68760

    *Ryuta Kamizono*

*   Allow precision option for MySQL datetimes.

    *Ryuta Kamizono*

*   Clear query cache on rollback.

    *Florian Weingarten*

*   Fixed setting of foreign_key for through associations while building of new record.

    Fixes #12698.

    *Ivan Antropov*

*   Fixed automatic inverse_of for models nested in module.

    *Andrew McCloud*

*   Fix `reaping_frequency` option when the value is a string.

    This usually happens when it is configured using `DATABASE_URL`.

    *korbin*

*   Fix error message when trying to create an associated record and the foreign
    key is missing.

    Before this fix the following exception was being raised:

        NoMethodError: undefined method `val' for #<Arel::Nodes::BindParam:0x007fc64d19c218>

    Now the message is:

        ActiveRecord::UnknownAttributeError: unknown attribute 'foreign_key' for Model.

    *Rafael Mendonça França*

*   Fix change detection problem for PostgreSQL bytea type and
    `ArgumentError: string contains null byte` exception with pg-0.18.

    Fixes #17680.

    *Lars Kanis*

*   When a table has a composite primary key, the `primary_key` method for
    SQLite3 and PostgreSQL adapters was only returning the first field of the key.
    Ensures that it will return nil instead, as Active Record doesn't support
    composite primary keys.

    Fixes #18070.

    *arthurnn*

*   Ensure `first!` and friends work on loaded associations.

    Fixes #18237.

    *Sean Griffin*

*   Dump the default `nil` for PostgreSQL UUID primary key.

    *Ryuta Kamizono*

*   Don't raise when writing an attribute with an out-of-range datetime passed
    by the user.

    *Grey Baker*

*   Fixes bug with 'ActiveRecord::Type::Numeric' that causes negative values to
    be marked as having changed when set to the same negative value.

    Fixes #18161.

    *Daniel Fox*


## Rails 4.2.0 (December 20, 2014) ##

*   Introduce `force: :cascade` option for `create_table`. Using this option
    will recreate tables even if they have dependent objects (like foreign keys).
    `db/schema.rb` now uses `force: :cascade`. This makes it possible to
    reload the schema when foreign keys are in place.

    *Matthew Draper*, *Yves Senn*

*   `db:schema:load` and `db:structure:load` no longer purge the database
    before loading the schema. This is left for the user to do.
    `db:test:prepare` will still purge the database.

    Fixes #17945.

    *Yves Senn*

*   Fix undesirable RangeError by Type::Integer. Add Type::UnsignedInteger.

    *Ryuta Kamizono*

*   Add `foreign_type` option to `has_one` and `has_many` association macros.

    This option enables to define the column name of associated object's type for polymorphic associations.

    *Ulisses Almeida, Kassio Borges*

*   `add_timestamps` and `remove_timestamps` now properly reversible with
    options.

    *Noam Gagliardi-Rabinovich*

*   Bring back `db:test:prepare` to synchronize the test database schema.

    Manual synchronization using `bin/rake db:test:prepare` is required
    when a migration is rolled-back, edited and reapplied.

    `ActiveRecord::Base.maintain_test_schema` now uses `db:test:prepare`
    to synchronize the schema. Plugins can use this task as a hook to
    provide custom behavior after the schema has been loaded.

    NOTE: `test:prepare` runs before the schema is synchronized.

    Fixes #17171, #15787.

    *Yves Senn*

*   Change `reflections` public api to return the keys as String objects.

    Fixes #16928.

    *arthurnn*

*   Renaming a table in pg also renames the primary key index.

    Fixes #12856

    *Sean Griffin*

*   Make it possible to access fixtures excluded by a `default_scope`.

    *Yves Senn*

*   Fix preloading of associations with a scope containing joins along with
    conditions on the joined association.

    *Siddharth Sharma*

*   Add `Table#name` to match `TableDefinition#name`.

    *Cody Cutrer*

*   Cache `CollectionAssociation#reader` proxies separately before and after
    the owner has been saved so that the proxy is not cached without the
    owner's id.

    *Ben Woosley*

*   `ActiveRecord::ReadOnlyRecord` now has a descriptive message.

    *Franky W.*

*   Fix preloading of associations which unscope a default scope.

    Fixes #11036.

    *Byron Bischoff*

*   Added SchemaDumper support for tables with jsonb columns.

    *Ted O'Meara*

*   Deprecate `sanitize_sql_hash_for_conditions` without replacement. Using a
    `Relation` for performing queries and updates is the prefered API.

    *Sean Griffin*

*   Queries now properly type cast values that are part of a join statement,
    even when using type decorators such as `serialize`.

    *Melanie Gilman & Sean Griffin*

*   MySQL enum type lookups, with values matching another type, no longer result
    in an endless loop.

    Fixes #17402.

    *Yves Senn*

*   Raise `ArgumentError` when the body of a scope is not callable.

    *Mauro George*

*   Use type column first in multi-column indexes created with `add-reference`.

    *Derek Prior*

*   Fix `Relation.rewhere` to work with Range values.

    *Dan Olson*

*   `AR::UnknownAttributeError` now includes the class name of a record.

        User.new(name: "Yuki Nishijima", project_attributes: {name: "kaminari"})
        # => ActiveRecord::UnknownAttributeError: unknown attribute 'name' for User.

    *Yuki Nishijima*

*   Fix a regression causing `after_create` callbacks to run before associated
    records are autosaved.

    Fixes #17209.

    *Agis Anastasopoulos*

*   Honor overridden `rack.test` in Rack environment for the connection
    management middleware.

    *Simon Eskildsen*

*   Add a truncate method to the connection.

    *Aaron Patterson*

*   Don't autosave unchanged has_one through records.

    *Alan Kennedy*, *Steve Parrington*

*   Do not dump foreign keys for ignored tables.

    *Yves Senn*

*   PostgreSQL adapter correctly dumps foreign keys targeting tables
    outside the schema search path.

    Fixes #16907.

    *Matthew Draper*, *Yves Senn*

*   When a thread is killed, rollback the active transaction, instead of
    committing it during the stack unwind. Previously, we could commit half-
    completed work. This fix only works for Ruby 2.0+; on 1.9, we can't
    distinguish a thread kill from an ordinary non-local (block) return, so must
    default to committing.

    *Chris Hanks*

*   A `NullRelation` should represent nothing. This fixes a bug where
    `Comment.where(post_id: Post.none)` returned a non-empty result.

    Fixes #15176.

    *Matthew Draper*, *Yves Senn*

*   Include default column limits in schema.rb. Allows defaults to be changed
    in the future without affecting old migrations that assumed old defaults.

    *Jeremy Kemper*

*   MySQL: schema.rb now includes TEXT and BLOB column limits.

    *Jeremy Kemper*

*   MySQL: correct LONGTEXT and LONGBLOB limits from 2GB to their true 4GB.

    *Jeremy Kemper*

*   SQLite3Adapter now checks for views in `table_exists?`. Fixes #14041.

    *Girish Sonawane*

*   Introduce `connection.supports_views?` to check whether the current adapter
    has support for SQL views. Connection adapters should define this method.

    *Yves Senn*

*   Allow included modules to override association methods.

    Fixes #16684.

    *Yves Senn*

*   Schema loading rake tasks (like `db:schema:load` and `db:setup`) maintain
    the database connection to the current environment.

    Fixes #16757.

    *Joshua Cody*, *Yves Senn*

*   MySQL: set the connection collation along with the charset.

    Sets the connection collation to the database collation configured in
    database.yml. Otherwise, `SET NAMES utf8mb4` will use the default
    collation for that charset (utf8mb4_general_ci) when you may have chosen
    a different collation, like utf8mb4_unicode_ci.

    This only applies to literal string comparisons, not column values, so it
    is unlikely to affect you.

    *Jeremy Kemper*

*   `default_sequence_name` from the PostgreSQL adapter returns a `String`.

    *Yves Senn*

*   Fix a regression where whitespaces were stripped from DISTINCT queries in
    PostgreSQL.

    *Agis Anastasopoulos*

    Fixes #16623.

*   Fix has_many :through relation merging failing when dynamic conditions are
    passed as a lambda with an arity of one.

    Fixes #16128.

    *Agis Anastasopoulos*

*   Fix `Relation#exists?` to work with polymorphic associations.

    Fixes #15821.

    *Kassio Borges*

*   Currently, Active Record rescues any errors raised within
    `after_rollback`/`after_create` callbacks and prints them to the logs.
    Future versions of Rails will not rescue these errors anymore and
    just bubble them up like the other callbacks.

    This commit adds an opt-in flag to enable not rescuing the errors.

    Example:

        # Do not swallow errors in after_commit/after_rollback callbacks.
        config.active_record.raise_in_transactional_callbacks = true

    Fixes #13460.

    *arthurnn*

*   Fix an issue where custom accessor methods (such as those generated by
    `enum`) with the same name as a global method are incorrectly overridden
    when subclassing.

    Fixes #16288.

    *Godfrey Chan*

*   `*_was` and `changes` now work correctly for in-place attribute changes as
    well.

    *Sean Griffin*

*   Fix regression on `after_commit` that did not fire with nested transactions.

    Fixes #16425.

    *arthurnn*

*   Do not try to write timestamps when a table has no timestamps columns.

    Fixes #8813.

    *Sergey Potapov*

*   `index_exists?` with `:name` option does verify specified columns.

    Example:

        add_index :articles, :title, name: "idx_title"

        # Before:
        index_exists? :articles, :title, name: "idx_title" # => `true`
        index_exists? :articles, :body, name: "idx_title" # => `true`

        # After:
        index_exists? :articles, :title, name: "idx_title" # => `true`
        index_exists? :articles, :body, name: "idx_title" # => `false`

    *Yves Senn*, *Matthew Draper*

*   `add_timestamps` and `t.timestamps` now require you to pass the `:null` option.
    Not passing the option is deprecated but the default is still `null: true`.
    With Rails 5 this will change to `null: false`.

    *Sean Griffin*

*   When calling `update_columns` on a record that is not persisted, the error
    message now reflects whether that object is a new record or has been
    destroyed.

    *Lachlan Sylvester*

*   Define `id_was` to get the previous value of the primary key.

    Currently when we call `id_was` and we have a custom primary key name,
    Active Record will return the current value of the primary key. This
    makes it impossible to correctly do an update operation if you change the
    id.

    Fixes #16413.

    *Rafael Mendonça França*

*   Deprecate `DatabaseTasks.load_schema` to act on the current connection.
    Use `.load_schema_current` instead. In the future `load_schema` will
    require the `configuration` to act on as an argument.

    *Yves Senn*

*   Fix automatic maintaining test schema to properly handle sql structure
    schema format.

    Fixes #15394.

    *Wojciech Wnętrzak*

*   Fix type casting to Decimal from Float with large precision.

    *Tomohiro Hashidate*

*   Deprecate `Reflection#source_macro`

    `Reflection#source_macro` is no longer needed in Active Record
    source so it has been deprecated. Code that used `source_macro`
    was removed in #16353.

    *Eileen M. Uchtitelle*, *Aaron Patterson*

*   No verbose backtrace by `db:drop` when database does not exist.

    Fixes #16295.

    *Kenn Ejima*

*   Add support for PostgreSQL JSONB.

    Example:

        create_table :posts do |t|
          t.jsonb :meta_data
        end

    *Philippe Creux*, *Chris Teague*

*   `db:purge` with MySQL respects `Rails.env`.

    *Yves Senn*

*   `change_column_default :table, :column, nil` with PostgreSQL will issue a
    `DROP DEFAULT` instead of a `DEFAULT NULL` query.

    Fixes #16261.

    *Matthew Draper*, *Yves Senn*

*   Allow to specify a type for the foreign key column in `references`
    and `add_reference`.

    Example:

        change_table :vehicle do |t|
          t.references :station, type: :uuid
        end

    *Andrey Novikov*, *Łukasz Sarnacki*

*   `create_join_table` removes a common prefix when generating the join table.
    This matches the existing behavior of HABTM associations.

    Fixes #13683.

    *Stefan Kanev*

*   Do not swallow errors on `compute_type` when having a bad `alias_method` on
    a class.

    *arthurnn*

*   PostgreSQL invalid `uuid` are convert to nil.

    *Abdelkader Boudih*

*   Restore 4.0 behavior for using serialize attributes with `JSON` as coder.

    With 4.1.x, `serialize` started returning a string when `JSON` was passed as
    the second attribute. It will now return a hash as per previous versions.

    Example:

        class Post < ActiveRecord::Base
          serialize :comment, JSON
        end

        class Comment
          include ActiveModel::Model
          attr_accessor :category, :text
        end

        post = Post.create!
        post.comment = Comment.new(category: "Animals", text: "This is a comment about squirrels.")
        post.save!

        # 4.0
        post.comment # => {"category"=>"Animals", "text"=>"This is a comment about squirrels."}

        # 4.1 before
        post.comment # => "#<Comment:0x007f80ab48ff98>"

        # 4.1 after
        post.comment # => {"category"=>"Animals", "text"=>"This is a comment about squirrels."}

    When using `JSON` as the coder in `serialize`, Active Record will use the
    new `ActiveRecord::Coders::JSON` coder which delegates its `dump/load` to
    `ActiveSupport::JSON.encode/decode`. This ensures special objects are dumped
    correctly using the `#as_json` hook.

    To keep the previous behaviour, supply a custom coder instead
    ([example](https://gist.github.com/jenncoop/8c4142bbe59da77daa63)).

    Fixes #15594.

    *Jenn Cooper*

*   Do not use `RENAME INDEX` syntax for MariaDB 10.0.

    Fixes #15931.

    *Jeff Browning*

*   Calling `#empty?` on a `has_many` association would use the value from the
    counter cache if one exists.

    *David Verhasselt*

*   Fix the schema dump generated for tables without constraints and with
    primary key with default value of custom PostgreSQL function result.

    Fixes #16111.

    *Andrey Novikov*

*   Fix the SQL generated when a `delete_all` is run on an association to not
    produce an `IN` statements.

    Before:

      UPDATE "categorizations" SET "category_id" = NULL WHERE
      "categorizations"."category_id" = 1 AND "categorizations"."id" IN (1, 2)

    After:

      UPDATE "categorizations" SET "category_id" = NULL WHERE
      "categorizations"."category_id" = 1

    *Eileen M. Uchitelle, Aaron Patterson*

*   Avoid type casting boolean and `ActiveSupport::Duration` values to numeric
    values for string columns. Otherwise, in some database, the string column
    values will be coerced to a numeric allowing false or 0.seconds match any
    string starting with a non-digit.

    Example:

        App.where(apikey: false) # => SELECT * FROM users WHERE apikey = '0'

    *Dylan Thacker-Smith*

*   Add a `:required` option to singular associations, providing a nicer
    API for presence validations on associations.

    *Sean Griffin*

*   Fix an error in `reset_counters` when associations have `select` scope.
    (Call to `count` generated invalid SQL.)

    *Cade Truitt*

*   After a successful `reload`, `new_record?` is always false.

    Fixes #12101.

    *Matthew Draper*

*   PostgreSQL renaming table doesn't attempt to rename non existent sequences.

    *Abdelkader Boudih*

*   Move 'dependent: :destroy' handling for `belongs_to`
    from `before_destroy` to `after_destroy` callback chain

    Fixes #12380.

    *Ivan Antropov*

*   Detect in-place modifications on String attributes.

    Before this change, an attribute modified in-place had to be marked as
    changed in order for it to be persisted in the database. Now it is no longer
    required.

    Before:

        user = User.first
        user.name << ' Griffin'
        user.name_will_change!
        user.save
        user.reload.name # => "Sean Griffin"

    After:

        user = User.first
        user.name << ' Griffin'
        user.save
        user.reload.name # => "Sean Griffin"

    *Sean Griffin*

*   Add `ActiveRecord::Base#validate!` that raises `RecordInvalid` if the record
    is invalid.

    *Bogdan Gusiev*, *Marc Schütz*

*   Support for adding and removing foreign keys. Foreign keys are now
    a part of `schema.rb`. This is supported by Mysql2Adapter, MysqlAdapter
    and PostgreSQLAdapter.

    Many thanks to *Matthew Higgins* for laying the foundation with his work on
    [foreigner](https://github.com/matthuhiggins/foreigner).

    Example:

        # within your migrations:
        add_foreign_key :articles, :authors
        remove_foreign_key :articles, :authors

    *Yves Senn*

*   Fix subtle bugs regarding attribute assignment on models with no primary
    key. `'id'` will no longer be part of the attributes hash.

    *Sean Griffin*

*   Deprecate automatic counter caches on `has_many :through`. The behavior was
    broken and inconsistent.

    *Sean Griffin*

*   `preload` preserves readonly flag for associations.

    See #15853.

    *Yves Senn*

*   Assume numeric types have changed if they were assigned to a value that
    would fail numericality validation, regardless of the old value. Previously
    this would only occur if the old value was 0.

    Example:

        model = Model.create!(number: 5)
        model.number = '5wibble'
        model.number_changed? # => true

    Fixes #14731.

    *Sean Griffin*

*   `reload` no longer merges with the existing attributes.
    The attribute hash is fully replaced. The record is put into the same state
    as it would be with `Model.find(model.id)`.

    *Sean Griffin*

*   The object returned from `select_all` must respond to `column_types`.
    If this is not the case a `NoMethodError` is raised.

    *Sean Griffin*

*   Detect in-place modifications of PG array types

    *Sean Griffin*

*   Add `bin/rake db:purge` task to empty the current database.

    *Yves Senn*

*   Deprecate `serialized_attributes` without replacement.

    *Sean Griffin*

*   Correctly extract IPv6 addresses from `DATABASE_URI`: the square brackets
    are part of the URI structure, not the actual host.

    Fixes #15705.

    *Andy Bakun*, *Aaron Stone*

*   Ensure both parent IDs are set on join records when both sides of a
    through association are new.

    *Sean Griffin*

*   `ActiveRecord::Dirty` now detects in-place changes to mutable values.
    Serialized attributes on ActiveRecord models will no longer save when
    unchanged.

    Fixes #8328.

    *Sean Griffin*

*   `Pluck` now works when selecting columns from different tables with the same
    name.

    Fixes #15649.

    *Sean Griffin*

*   Remove `cache_attributes` and friends. All attributes are cached.

    *Sean Griffin*

*   Remove deprecated method `ActiveRecord::Base.quoted_locking_column`.

    *Akshay Vishnoi*

*   `ActiveRecord::FinderMethods.find` with block can handle proc parameter as
    `Enumerable#find` does.

    Fixes #15382.

    *James Yang*

*   Make timezone aware attributes work with PostgreSQL array columns.

    Fixes #13402.

    *Kuldeep Aggarwal*, *Sean Griffin*

*   `ActiveRecord::SchemaMigration` has no primary key regardless of the
    `primary_key_prefix_type` configuration.

    Fixes #15051.

    *JoseLuis Torres*, *Yves Senn*

*   `rake db:migrate:status` works with legacy migration numbers like `00018_xyz.rb`.

    Fixes #15538.

    *Yves Senn*

*   Baseclass becomes! subclass.

    Before this change, a record which changed its STI type, could not be
    updated.

    Fixes #14785.

    *Matthew Draper*, *Earl St Sauver*, *Edo Balvers*

*   Remove deprecated `ActiveRecord::Migrator.proper_table_name`. Use the
    `proper_table_name` instance method on `ActiveRecord::Migration` instead.

    *Akshay Vishnoi*

*   Fix regression on eager loading association based on SQL query rather than
    existing column.

    Fixes #15480.

    *Lauro Caetano*, *Carlos Antonio da Silva*

*   Deprecate returning `nil` from `column_for_attribute` when no column exists.
    It will return a null object in Rails 5.0

    *Sean Griffin*

*   Implemented `ActiveRecord::Base#pretty_print` to work with PP.

    *Ethan*

*   Preserve type when dumping PostgreSQL point, bit, bit varying and money
    columns.

    *Yves Senn*

*   New records remain new after YAML serialization.

    *Sean Griffin*

*   PostgreSQL support default values for enum types. Fixes #7814.

    *Yves Senn*

*   PostgreSQL `default_sequence_name` respects schema. Fixes #7516.

    *Yves Senn*

*   Fix `columns_for_distinct` of PostgreSQL adapter to work correctly
    with orders without sort direction modifiers.

    *Nikolay Kondratyev*

*   PostgreSQL `reset_pk_sequence!` respects schemas. Fixes #14719.

    *Yves Senn*

*   Keep PostgreSQL `hstore` and `json` attributes as `Hash` in `@attributes`.
    Fixes duplication in combination with `store_accessor`.

    Fixes #15369.

    *Yves Senn*

*   `rake railties:install:migrations` respects the order of railties.

    *Arun Agrawal*

*   Fix redefine a `has_and_belongs_to_many` inside inherited class
    Fixing regression case, where redefining the same `has_and_belongs_to_many`
    definition into a subclass would raise.

    Fixes #14983.

    *arthurnn*

*   Fix `has_and_belongs_to_many` public reflection.
    When defining a `has_and_belongs_to_many`, internally we convert that to two has_many.
    But as `reflections` is a public API, people expect to see the right macro.

    Fixes #14682.

    *arthurnn*

*   Fix serialization for records with an attribute named `format`.

    Fixes #15188.

    *Godfrey Chan*

*   When a `group` is set, `sum`, `size`, `average`, `minimum` and `maximum`
    on a NullRelation should return a Hash.

    *Kuldeep Aggarwal*

*   Fix serialized fields returning serialized data after being updated with
    `update_column`.

    *Simon Hørup Eskildsen*

*   Fix polymorphic eager loading when using a String as foreign key.

    Fixes #14734.

    *Lauro Caetano*

*   Change belongs_to touch to be consistent with timestamp updates

    If a model is set up with a belongs_to: touch relationship the parent
    record will only be touched if the record was modified. This makes it
    consistent with timestamp updating on the record itself.

    *Brock Trappitt*

*   Fix the inferred table name of a `has_and_belongs_to_many` auxiliary
    table inside a schema.

    Fixes #14824.

    *Eric Chahin*

*   Remove unused `:timestamp` type. Transparently alias it to `:datetime`
    in all cases. Fixes inconsistencies when column types are sent outside of
    `ActiveRecord`, such as for XML Serialization.

    *Sean Griffin*

*   Fix bug that added `table_name_prefix` and `table_name_suffix` to
    extension names in PostgreSQL when migrating.

    *Joao Carlos*

*   The `:index` option in migrations, which previously was only available for
    `references`, now works with any column types.

    *Marc Schütz*

*   Add support for counter name to be passed as parameter on `CounterCache::ClassMethods#reset_counters`.

    *jnormore*

*   Restrict deletion of record when using `delete_all` with `uniq`, `group`, `having`
    or `offset`.

    In these cases the generated query ignored them and that caused unintended
    records to be deleted.

    Fixes #11985.

    *Leandro Facchinetti*

*   Floats with limit >= 25 that get turned into doubles in MySQL no longer have
    their limit dropped from the schema.

    Fixes #14135.

    *Aaron Nelson*

*   Fix how to calculate associated class name when using namespaced `has_and_belongs_to_many`
    association.

    Fixes #14709.

    *Kassio Borges*

*   `ActiveRecord::Relation::Merger#filter_binds` now compares equivalent symbols and
    strings in column names as equal.

    This fixes a rare case in which more bind values are passed than there are
    placeholders for them in the generated SQL statement, which can make PostgreSQL
    throw a `StatementInvalid` exception.

    *Nat Budin*

*   Fix `stored_attributes` to correctly merge the details of stored
    attributes defined in parent classes.

    Fixes #14672.

    *Brad Bennett*, *Jessica Yao*, *Lakshmi Parthasarathy*

*   `change_column_default` allows `[]` as argument to `change_column_default`.

    Fixes #11586.

    *Yves Senn*

*   Handle `name` and `"char"` column types in the PostgreSQL adapter.

    `name` and `"char"` are special character types used internally by
    PostgreSQL and are used by internal system catalogs. These field types
    can sometimes show up in structure-sniffing queries that feature internal system
    structures or with certain PostgreSQL extensions.

    *J Smith*, *Yves Senn*

*   Fix `PostgreSQLAdapter::OID::Float#type_cast` to convert Infinity and
    NaN PostgreSQL values into a native Ruby `Float::INFINITY` and `Float::NAN`

    Before:

        Point.create(value: 1.0/0)
        Point.last.value # => 0.0

    After:

        Point.create(value: 1.0/0)
        Point.last.value # => Infinity

    *Innokenty Mikhailov*

*   Allow the PostgreSQL adapter to handle bigserial primary key types again.

    Fixes #10410.

    *Patrick Robertson*

*   Deprecate joining, eager loading and preloading of instance dependent
    associations without replacement. These operations happen before instances
    are created. The current behavior is unexpected and can result in broken
    behavior.

    Fixes #15024.

    *Yves Senn*

*   Fix `has_and_belongs_to_many` CollectionAssociation size calculations.

    `has_and_belongs_to_many` should fall back to using the normal CollectionAssociation's
    size calculation if the collection is not cached or loaded.

    Fixes #14913, #14914.

    *Fred Wu*

*   Return a non zero status when running `rake db:migrate:status` and migration table does
    not exist.

    *Paul B.*

*   Add support for module-level `table_name_suffix` in models.

    This makes `table_name_suffix` work the same way as `table_name_prefix` when
    using namespaced models.

    *Jenner LaFave*

*   Revert the behaviour of `ActiveRecord::Relation#join` changed through 4.0 => 4.1 to 4.0.

    In 4.1.0 `Relation#join` is delegated to `Arel#SelectManager`.
    In 4.0 series it is delegated to `Array#join`.

    *Bogdan Gusiev*

*   Log nil binary column values correctly.

    When an object with a binary column is updated with a nil value
    in that column, the SQL logger would throw an exception when trying
    to log that nil value. This only occurs when updating a record
    that already has a non-nil value in that column since an initial nil
    value isn't included in the SQL anyway (at least, when dirty checking
    is enabled.) The column's new value will now be logged as `<NULL binary data>`
    to parallel the existing `<N bytes of binary data>` for non-nil values.

    *James Coleman*

*   Rails will now pass a custom validation context through to autosave associations
    in order to validate child associations with the same context.

    Fixes #13854.

    *Eric Chahin*, *Aaron Nelson*, *Kevin Casey*

*   Stringify all variables keys of MySQL connection configuration.

    When `sql_mode` variable for MySQL adapters set in configuration as `String`
    was ignored and overwritten by strict mode option.

    Fixes #14895.

    *Paul Nikitochkin*

*   Ensure SQLite3 statements are closed on errors.

    Fixes #13631.

    *Timur Alperovich*

*   Give `ActiveRecord::PredicateBuilder` private methods the privacy they deserve.

    *Hector Satre*

*   When using a custom `join_table` name on a `habtm`, rails was not saving it
    on Reflections. This causes a problem when rails loads fixtures, because it
    uses the reflections to set database with fixtures.

    Fixes #14845.

    *Kassio Borges*

*   Reset the cache when modifying a Relation with cached Arel.
    Additionally display a warning message to make the user aware.

    *Yves Senn*

*   PostgreSQL should internally use `:datetime` consistently for TimeStamp. Assures
    different spellings of timestamps are treated the same.

    Example:

        mytimestamp.simplified_type('timestamp without time zone')
        # => :datetime
        mytimestamp.simplified_type('timestamp(6) without time zone')
        # => also :datetime (previously would be :timestamp)

    See #14513.

    *Jefferson Lai*

*   `ActiveRecord::Base.no_touching` no longer triggers callbacks or start empty transactions.

    Fixes #14841.

    *Lucas Mazza*

*   Fix name collision with `Array#select!` with `Relation#select!`.

    Fixes #14752.

    *Earl St Sauver*

*   Fix unexpected behavior for `has_many :through` associations going through
    a scoped `has_many`.

    If a `has_many` association is adjusted using a scope, and another
    `has_many :through` uses this association, then the scope adjustment is
    unexpectedly neglected.

    Fixes #14537.

    *Jan Habermann*

*   `@destroyed` should always be set to `false` when an object is duped.

    *Kuldeep Aggarwal*

*   Enable `has_many` associations to support irregular inflections.

    Fixes #8928.

    *arthurnn*, *Javier Goizueta*

*   Fix `count` used with a grouping not returning a Hash.

    Fixes #14721.

    *Eric Chahin*

*   `sanitize_sql_like` helper method to escape a string for safe use in an SQL
    LIKE statement.

    Example:

        class Article
          def self.search(term)
            where("title LIKE ?", sanitize_sql_like(term))
          end
        end

        Article.search("20% _reduction_")
        # => Query looks like "... title LIKE '20\% \_reduction\_' ..."

    *Rob Gilson*, *Yves Senn*

*   Do not quote uuid default value on `change_column`.

    Fixes #14604.

    *Eric Chahin*

*   The comparison between `Relation` and `CollectionProxy` should be consistent.

    Example:

        author.posts == Post.where(author_id: author.id)
        # => true
        Post.where(author_id: author.id) == author.posts
        # => true

    Fixes #13506.

    *Lauro Caetano*

*   Calling `delete_all` on an unloaded `CollectionProxy` no longer
    generates an SQL statement containing each id of the collection:

    Before:

        DELETE FROM `model` WHERE `model`.`parent_id` = 1
        AND `model`.`id` IN (1, 2, 3...)

    After:

        DELETE FROM `model` WHERE `model`.`parent_id` = 1

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   Fix invalid SQL when aggregate methods (`empty?`, `any?`, `count`) used
    with `select`.

    Fixes #13648.

    *Simon Woker*

*   PostgreSQL adapter only warns once for every missing OID per connection.

    Fixes #14275.

    *Matthew Draper*, *Yves Senn*

*   PostgreSQL adapter automatically reloads it's type map when encountering
    unknown OIDs.

    Fixes #14678.

    *Matthew Draper*, *Yves Senn*

*   Fix insertion of records via `has_many :through` association with scope.

    Fixes #3548.

    *Ivan Antropov*

*   Auto-generate stable fixture UUIDs on PostgreSQL.

    Fixes #11524.

    *Roderick van Domburg*

*   Fix a problem where an enum would overwrite values of another enum with the
    same name in an unrelated class.

    Fixes #14607.

    *Evan Whalen*

*   PostgreSQL and SQLite string columns no longer have a default limit of 255.

    Fixes #13435, #9153.

    *Vladimir Sazhin*, *Toms Mikoss*, *Yves Senn*

*   Make possible to have an association called `records`.

    Fixes #11645.

    *prathamesh-sonpatki*

*   `to_sql` on an association now matches the query that is actually executed, where it
    could previously have incorrectly accrued additional conditions (e.g. as a result of
    a previous query). `CollectionProxy` now always defers to the association scope's
    `arel` method so the (incorrect) inherited one should be entirely concealed.

    Fixes #14003.

    *Jefferson Lai*

*   Block a few default Class methods as scope name.

    For instance, this will raise:

        scope :public, -> { where(status: 1) }

    *arthurnn*

*   Fix error when using `with_options` with lambda.

    Fixes #9805.

    *Lauro Caetano*

*   Switch `sqlite3:///` URLs (which were temporarily
    deprecated in 4.1) from relative to absolute.

    If you still want the previous interpretation, you should replace
    `sqlite3:///my/path` with `sqlite3:my/path`.

    *Matthew Draper*

*   Treat blank UUID values as `nil`.

    Example:

        Sample.new(uuid_field: '') #=> <Sample id: nil, uuid_field: nil>

    *Dmitry Lavrov*

*   Enable support for materialized views on PostgreSQL >= 9.3.

    *Dave Lee*

*   The PostgreSQL adapter supports custom domains. Fixes #14305.

    *Yves Senn*

*   PostgreSQL `Column#type` is now determined through the corresponding OID.
    The column types stay the same except for enum columns. They no longer have
    `nil` as type but `enum`.

    See #7814.

    *Yves Senn*

*   Fix error when specifying a non-empty default value on a PostgreSQL array
    column.

    Fixes #10613.

    *Luke Steensen*

*   Fix error where `.persisted?` throws SystemStackError for an unsaved model with a
    custom primary key that did not save due to validation error.

    Fixes #14393.

    *Chris Finne*

*   Introduce `validate` as an alias for `valid?`.

    This is more intuitive when you want to run validations but don't care about the return value.

    *Henrik Nyh*

*   Create indexes inline in CREATE TABLE for MySQL.

    This is important, because adding an index on a temporary table after it has been created
    would commit the transaction.

    It also allows creating and dropping indexed tables with fewer queries and fewer permissions
    required.

    Example:

        create_table :temp, temporary: true, as: "SELECT id, name, zip FROM a_really_complicated_query" do |t|
          t.index :zip
        end
        # => CREATE TEMPORARY TABLE temp (INDEX (zip)) AS SELECT id, name, zip FROM a_really_complicated_query

    *Cody Cutrer*, *Steve Rice*, *Rafael Mendonça Franca*

*   Use singular table name in generated migrations when
    `ActiveRecord::Base.pluralize_table_names` is `false`.

    Fixes #13426.

    *Kuldeep Aggarwal*

*   `touch` accepts many attributes to be touched at once.

    Example:

        # touches :signed_at, :sealed_at, and :updated_at/on attributes.
        Photo.last.touch(:signed_at, :sealed_at)

    *James Pinto*

*   `rake db:structure:dump` only dumps schema information if the schema
    migration table exists.

    Fixes #14217.

    *Yves Senn*

*   Reap connections that were checked out by now-dead threads, instead
    of waiting until they disconnect by themselves. Before this change,
    a suitably constructed series of short-lived threads could starve
    the connection pool, without ever having more than a couple alive at
    the same time.

    *Matthew Draper*

*   `pk_and_sequence_for` now ensures that only the pg_depend entries
    pointing to pg_class, and thus only sequence objects, are considered.

    *Josh Williams*

*   `where.not` adds `references` for `includes` like normal `where` calls do.

    Fixes #14406.

    *Yves Senn*

*   Extend fixture `$LABEL` replacement to allow string interpolation.

    Example:

        martin:
          email: $LABEL@email.com

        users(:martin).email # => martin@email.com

    *Eric Steele*

*   Add support for `Relation` be passed as parameter on `QueryCache#select_all`.

    Fixes #14361.

    *arthurnn*

*   Passing an Active Record object to `find` or `exists?` is now deprecated.
    Call `.id` on the object first.

    *Aaron Patterson*

*   Only use BINARY for MySQL case sensitive uniqueness check when column
    has a case insensitive collation.

    *Ryuta Kamizono*

*   Support for MySQL 5.6 fractional seconds.

    *arthurnn*, *Tatsuhiko Miyagawa*

*   Support for PostgreSQL `citext` data type enabling case-insensitive
   `where` values without needing to wrap in UPPER/LOWER sql functions.

    *Troy Kruthoff*, *Lachlan Sylvester*

*   Only save has_one associations if record has changes.
    Previously after save related callbacks, such as `#after_commit`, were triggered when the has_one
    object did not get saved to the db.

    *Alan Kennedy*

*   Allow strings to specify the `#order` value.

    Example:

        Model.order(id: 'asc').to_sql == Model.order(id: :asc).to_sql

    *Marcelo Casiraghi*, *Robin Dupret*

*   Dynamically register PostgreSQL enum OIDs. This prevents "unknown OID"
    warnings on enum columns.

    *Dieter Komendera*

*   `includes` is able to detect the right preloading strategy when string
    joins are involved.

    Fixes #14109.

    *Aaron Patterson*, *Yves Senn*

*   Fix error with validation with enum fields for records where the value for
    any enum attribute is always evaluated as 0 during uniqueness validation.

    Fixes #14172.

    *Vilius Luneckas* *Ahmed AbouElhamayed*

*   `before_add` callbacks are fired before the record is saved on
    `has_and_belongs_to_many` associations *and* on `has_many :through`
    associations.  Before this change, `before_add` callbacks would be fired
    before the record was saved on `has_and_belongs_to_many` associations, but
    *not* on `has_many :through` associations.

    Fixes #14144.

*   Fix STI classes not defining an attribute method if there is a conflicting
    private method defined on its ancestors.

    Fixes #11569.

    *Godfrey Chan*

*   Coerce strings when reading attributes. Fixes #10485.

    Example:

        book = Book.new(title: 12345)
        book.save!
        book.title # => "12345"

    *Yves Senn*

*   Deprecate half-baked support for PostgreSQL range values with excluding beginnings.
    We currently map PostgreSQL ranges to Ruby ranges. This conversion is not fully
    possible because the Ruby range does not support excluded beginnings.

    The current solution of incrementing the beginning is not correct and is now
    deprecated. For subtypes where we don't know how to increment (e.g. `#succ`
    is not defined) it will raise an `ArgumentException` for ranges with excluding
    beginnings.

    *Yves Senn*

*   Support for user created range types in PostgreSQL.

    *Yves Senn*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/activerecord/CHANGELOG.md) for previous changes.
