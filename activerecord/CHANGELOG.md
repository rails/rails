*   Fix through associations using scopes having the scope merged multiple
    times.

    Fixes #20721.
    Fixes #20727.

    *Sean Griffin*

*   `ActiveRecord::Base.dump_schema_after_migration` applies migration tasks
    other than `db:migrate`. (eg. `db:rollback`, `db:migrate:dup`, ...)

    Fixes #20743.

    *Yves Senn*

*   Add alternate syntax to make `change_column_default` reversible.

    User can pass in `:from` and `:to` to make `change_column_default` command
    become reversible.

    Example:

        change_column_default :posts, :status, from: nil, to: "draft"
        change_column_default :users, :authorized, from: true, to: false

    *Prem Sichanugrist*

*   Prevent error when using `force_reload: true` on an unassigned polymorphic
    belongs_to association.

    Fixes #20426.

    *James Dabbs*

*   Correctly raise `ActiveRecord::AssociationTypeMismatch` when assigning
    a wrong type to a namespaced association.

    Fixes #20545.

    *Diego Carrion*

*   `validates_absence_of` respects `marked_for_destruction?`.

    Fixes #20449.

    *Yves Senn*

*   Include the `Enumerable` module in `ActiveRecord::Relation`

    *Sean Griffin & bogdan*

*   Use `Enumerable#sum` in `ActiveRecord::Relation` if a block is given.

    *Sean Griffin*

*   Let `WITH` queries (Common Table Expressions) be explainable.

    *Vladimir Kochnev*

*   Make `remove_index :table, :column` reversible.

    *Yves Senn*

*   Fixed an error which would occur in dirty checking when calling
    `update_attributes` from a getter.

    Fixes #20531.

    *Sean Griffin*

*   Make `remove_foreign_key` reversible. Any foreign key options must be
    specified, similar to `remove_column`.

    *Aster Ryan*

*   Add `:enum_prefix`/`:enum_suffix` option to `enum` definition.

    Fixes #17511, #17415.

    *Igor Kapkov*

*   Correctly handle decimal arrays with defaults in the schema dumper.

    Fixes #20515.

    *Sean Griffin & jmondo*

*   Deprecate the PostgreSQL `:point` type in favor of a new one which will return
    `Point` objects instead of an `Array`

    *Sean Griffin*

*   Ensure symbols passed to `ActiveRecord::Relation#select` are always treated
    as columns.

    Fixes #20360.

    *Sean Griffin*

*   Do not set `sql_mode` if `strict: :default` is specified.

        ```
        # database.yml
        production:
          adapter: mysql2
          database: foo_prod
          user: foo
          strict: :default
        ```

    *Ryuta Kamizono*

*   Allow proc defaults to be passed to the attributes API. See documentation
    for examples.

    *Sean Griffin*, *Kir Shatrov*

*   SQLite: `:collation` support for string and text columns.

    Example:

        create_table :foo do |t|
          t.string :string_nocase, collation: 'NOCASE'
          t.text :text_rtrim, collation: 'RTRIM'
        end

        add_column :foo, :title, :string, collation: 'RTRIM'

        change_column :foo, :title, :string, collation: 'NOCASE'

    *Akshay Vishnoi*

*   Allow the use of symbols or strings to specify enum values in test
    fixtures:

        awdr:
          title: "Agile Web Development with Rails"
          status: :proposed

    *George Claghorn*

*   Clear query cache when `ActiveRecord::Base#reload` is called.

    *Shane Hender, Pierre Nespo*

*   Include stored procedures and function on the MySQL structure dump.

    *Jonathan Worek*

*   Pass `:extend` option for `has_and_belongs_to_many` associations to the
    underlying `has_many :through`.

    *Jaehyun Shin*

*   Deprecate `Relation#uniq` use `Relation#distinct` instead.

    See #9683.

    *Yves Senn*

*   Allow single table inheritance instantiation to work when storing
    demodulized class names.

    *Alex Robbin*

*   Correctly pass MySQL options when using `structure_dump` or
    `structure_load`.

    Specifically, it fixes an issue when using SSL authentication.

    *Alex Coomans*

*   Dump indexes in `create_table` instead of `add_index`.

    If the adapter supports indexes in `create_table`, generated SQL is
    slightly more efficient.

    *Ryuta Kamizono*

*   Correctly dump `:options` on `create_table` for MySQL.

    *Ryuta Kamizono*

*   PostgreSQL: `:collation` support for string and text columns.

    Example:

        create_table :foos do |t|
          t.string :string_en, collation: 'en_US.UTF-8'
          t.text   :text_ja,   collation: 'ja_JP.UTF-8'
        end

    *Ryuta Kamizono*

*   Make `unscope` aware of "less than" and "greater than" conditions.

    *TAKAHASHI Kazuaki*

*   `find_by` and `find_by!` raise `ArgumentError` when called without
    arguments.

    *Kohei Suzuki*

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

*   Autosave existing records on a has many through association when the parent
    is new.

    Fixes #19782.

    *Sean Griffin*

*   Fixed a bug where uniqueness validations would error on out of range values,
    even if an validation should have prevented it from hitting the database.

    *Andrey Voronkov*

*   MySQL: `:charset` and `:collation` support for string and text columns.

    Example:

        create_table :foos do |t|
          t.string :string_utf8_bin, charset: 'utf8', collation: 'utf8_bin'
          t.text   :text_ascii,      charset: 'ascii'
        end

    *Ryuta Kamizono*

*   Foreign key related methods in the migration DSL respect
    `ActiveRecord::Base.pluralize_table_names = false`.

    Fixes #19643.

    *Mehmet Emin İNAÇ*

*   Reduce memory usage from loading types on PostgreSQL.

    Fixes #19578.

    *Sean Griffin*

*   Add `config.active_record.warn_on_records_fetched_greater_than` option.

    When set to an integer, a warning will be logged whenever a result set
    larger than the specified size is returned by a query.

    Fixes #16463.

    *Jason Nochlin*

*   Ignore `.psqlrc` when loading database structure.

    *Jason Weathered*

*   Fix referencing wrong table aliases while joining tables of has many through
    association (only when calling calculation methods).

    Fixes #19276.

    *pinglamb*

*   Correctly persist a serialized attribute that has been returned to
    its default value by an in-place modification.

    Fixes #19467.

    *Matthew Draper*

*   Fix generating the schema file when using PostgreSQL `BigInt[]` data type.
    Previously the `limit: 8` was not coming through, and this caused it to
    become `Int[]` data type after rebuilding from the schema.

    Fixes #19420.

    *Jake Waller*

*   Reuse the `CollectionAssociation#reader` cache when the foreign key is
    available prior to save.

    *Ben Woosley*

*   Add `config.active_record.dump_schemas` to fix `db:structure:dump`
    when using schema_search_path and PostgreSQL extensions.

    Fixes #17157.

    *Ryan Wallace*

*   Renaming `use_transactional_fixtures` to `use_transactional_tests` for clarity.

    Fixes #18864.

    *Brandon Weiss*

*   Increase pg gem version requirement to `~> 0.18`. Earlier versions of the
    pg gem are known to have problems with Ruby 2.2.

    *Matt Brictson*

*   Correctly dump `serial` and `bigserial`.

    *Ryuta Kamizono*

*   Fix default `format` value in `ActiveRecord::Tasks::DatabaseTasks#schema_file`.

    *James Cox*

*   Don't enroll records in the transaction if they don't have commit callbacks.
    This was causing a memory leak when creating many records inside a transaction.

    Fixes #15549.

    *Will Bryant*, *Aaron Patterson*

*   Correctly create through records when created on a has many through
    association when using `where`.

    Fixes #19073.

    *Sean Griffin*

*   Add `SchemaMigration.create_table` support for any unicode charsets with MySQL.

    *Ryuta Kamizono*

*   PostgreSQL no longer disables user triggers if system triggers can't be
    disabled. Disabling user triggers does not fulfill what the method promises.
    Rails currently requires superuser privileges for this method.

    If you absolutely rely on this behavior, consider patching
    `disable_referential_integrity`.

    *Yves Senn*

*   Restore aborted transaction state when `disable_referential_integrity` fails
    due to missing permissions.

    *Toby Ovod-Everett*, *Yves Senn*

*   In PostgreSQL, print a warning message if `disable_referential_integrity`
    fails due to missing permissions.

    *Andrey Nering*, *Yves Senn*

*   Allow a `:limit` option for MySQL bigint primary key support.

    Example:

        create_table :foos, id: :primary_key, limit: 8 do |t|
        end

        # or

        create_table :foos, id: false do |t|
          t.primary_key :id, limit: 8
        end

    *Ryuta Kamizono*

*   `belongs_to` will now trigger a validation error by default if the association is not present.
    You can turn this off on a per-association basis with `optional: true`.
    (Note this new default only applies to new Rails apps that will be generated with
    `config.active_record.belongs_to_required_by_default = true` in initializer.)

    *Josef Šimánek*

*   Fixed `ActiveRecord::Relation#becomes!` and `changed_attributes` issues for type
    columns.

    Fixes #17139.

    *Miklos Fazekas*

*   Format the time string according to the precision of the time column.

    *Ryuta Kamizono*

*   Allow a `:precision` option for time type columns.

    *Ryuta Kamizono*

*   Add `ActiveRecord::Base.suppress` to prevent the receiver from being saved
    during the given block.

    For example, here's a pattern of creating notifications when new comments
    are posted. (The notification may in turn trigger an email, a push
    notification, or just appear in the UI somewhere):

        class Comment < ActiveRecord::Base
          belongs_to :commentable, polymorphic: true
          after_create -> { Notification.create! comment: self,
            recipients: commentable.recipients }
        end

    That's what you want the bulk of the time. A new comment creates a new
    Notification. There may be edge cases where you don't want that, like
    when copying a commentable and its comments, in which case write a
    concern with something like this:

        module Copyable
          def copy_to(destination)
            Notification.suppress do
              # Copy logic that creates new comments that we do not want triggering
              # notifications.
            end
          end
        end

    *Michael Ryan*

*   `:time` option added for `#touch`.

    Fixes #18905.

    *Hyonjee Joo*

*   Deprecate passing of `start` value to `find_in_batches` and `find_each`
    in favour of `begin_at` value.

    *Vipul A M*

*   Add `foreign_key_exists?` method.

    *Tõnis Simo*

*   Use SQL COUNT and LIMIT 1 queries for `none?` and `one?` methods
    if no block or limit is given, instead of loading the entire
    collection into memory. This applies to relations (e.g. `User.all`)
    as well as associations (e.g. `account.users`)

        # Before:

        users.none?
        # SELECT "users".* FROM "users"

        users.one?
        # SELECT "users".* FROM "users"

        # After:

        users.none?
        # SELECT 1 AS one FROM "users" LIMIT 1

        users.one?
        # SELECT COUNT(*) FROM "users"

    *Eugene Gilburg*

*   Have `enum` perform type casting consistently with the rest of Active
    Record, such as `where`.

    *Sean Griffin*

*   `scoping` no longer pollutes the current scope of sibling classes when using
    STI. e.x.

        StiOne.none.scoping do
          StiTwo.all
        end

    Fixes #18806.

    *Sean Griffin*

*   `remove_reference` with `foreign_key: true` removes the foreign key before
    removing the column. This fixes a bug where it was not possible to remove
    the column on MySQL.

    Fixes #18664.

    *Yves Senn*

*   `find_in_batches` now accepts an `:end_at` parameter that complements the `:start`
     parameter to specify where to stop batch processing.

    *Vipul A M*

*   Fix a rounding problem for PostgreSQL timestamp columns.

    If a timestamp column has a precision specified, it needs to
    format according to that.

    *Ryuta Kamizono*

*   Respect the database default charset for `schema_migrations` table.

    The charset of `version` column in `schema_migrations` table depends
    on the database default charset and collation rather than the encoding
    of the connection.

    *Ryuta Kamizono*

*   Raise `ArgumentError` when passing `nil` or `false` to `Relation#merge`.

    These are not valid values to merge in a relation, so it should warn users
    early.

    *Rafael Mendonça França*

*   Use `SCHEMA` instead of `DB_STRUCTURE` for specifying a structure file.

    This makes the db:structure tasks consistent with test:load_structure.

    *Dieter Komendera*

*   Respect custom primary keys for associations when calling `Relation#where`

    Fixes #18813.

    *Sean Griffin*

*   Fix several edge cases which could result in a counter cache updating
    twice or not updating at all for `has_many` and `has_many :through`.

    Fixes #10865.

    *Sean Griffin*

*   Foreign keys added by migrations were given random, generated names. This
    meant a different `structure.sql` would be generated every time a developer
    ran migrations on their machine.

    The generated part of foreign key names is now a hash of the table name and
    column name, which is consistent every time you run the migration.

    *Chris Sinjakli*

*   Validation errors would be raised for parent records when an association
    was saved when the parent had `validate: false`. It should not be the
    responsibility of the model to validate an associated object unless the
    object was created or modified by the parent.

    This fixes the issue by skipping validations if the parent record is
    persisted, not changed, and not marked for destruction.

    Fixes #17621.

    *Eileen M. Uchitelle, Aaron Patterson*

*   Fix n+1 query problem when eager loading nil associations (fixes #18312)

    *Sammy Larbi*

*   Change the default error message from `can't be blank` to `must exist` for
    the presence validator of the `:required` option on `belongs_to`/`has_one`
    associations.

    *Henrik Nygren*

*   Fixed `ActiveRecord::Relation#group` method when an argument is an SQL
    reserved keyword:

    Example:

        SplitTest.group(:key).count
        Property.group(:value).count

    *Bogdan Gusiev*

*   Added the `#or` method on `ActiveRecord::Relation`, allowing use of the OR
    operator to combine WHERE or HAVING clauses.

    Example:

        Post.where('id = 1').or(Post.where('id = 2'))
        # => SELECT * FROM posts WHERE (id = 1) OR (id = 2)

    *Sean Griffin*, *Matthew Draper*, *Gael Muller*, *Olivier El Mekki*

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
    ASCII-8BIT string with invalid UTF-8 bytes on SQLite3), no longer error on
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

*   Add `ActiveRecord::Base#accessed_fields`, which can be used to quickly
    discover which fields were read from a model when you are looking to only
    select the data you need from the database.

    *Sean Griffin*

*   Introduce the `:if_exists` option for `drop_table`.

    Example:

        drop_table(:posts, if_exists: true)

    That would execute:

        DROP TABLE IF EXISTS posts

    If the table doesn't exist, `if_exists: false` (the default) raises an
    exception whereas `if_exists: true` does nothing.

    *Cody Cutrer*, *Stefan Kanev*, *Ryuta Kamizono*

*   Don't run SQL if attribute value is not changed for update_attribute method.

    *Prathamesh Sonpatki*

*   `time` columns can now get affected by `time_zone_aware_attributes`. If you have
    set `config.time_zone` to a value other than `'UTC'`, they will be treated
    as in that time zone by default in Rails 5.1. If this is not the desired
    behavior, you can set

        ActiveRecord::Base.time_zone_aware_types = [:datetime]

    A deprecation warning will be emitted if you have a `:time` column, and have
    not explicitly opted out.

    Fixes #3145.

    *Sean Griffin*

*   Tests now run after_commit callbacks. You no longer have to declare
    `uses_transaction ‘test name’` to test the results of an after_commit.

    after_commit callbacks run after committing a transaction whose parent
    is not `joinable?`: un-nested transactions, transactions within test cases,
    and transactions in `console --sandbox`.

    *arthurnn*, *Ravil Bayramgalin*, *Matthew Draper*

*   `nil` as a value for a binary column in a query no longer logs as
    "<NULL binary data>", and instead logs as just "nil".

    *Sean Griffin*

*   `attribute_will_change!` will no longer cause non-persistable attributes to
    be sent to the database.

    Fixes #18407.

    *Sean Griffin*

*   Remove support for the `protected_attributes` gem.

    *Carlos Antonio da Silva*, *Roberto Miranda*

*   Fix accessing of fixtures having non-string labels like Fixnum.

    *Prathamesh Sonpatki*

*   Remove deprecated support to preload instance-dependent associations.

    *Yves Senn*

*   Remove deprecated support for PostgreSQL ranges with exclusive lower bounds.

    *Yves Senn*

*   Remove deprecation when modifying a relation with cached Arel.
    This raises an `ImmutableRelation` error instead.

    *Yves Senn*

*   Added `ActiveRecord::SecureToken` in order to encapsulate generation of
    unique tokens for attributes in a model using `SecureRandom`.

    *Roberto Miranda*

*   Change the behavior of boolean columns to be closer to Ruby's semantics.

    Before this change we had a small set of "truthy", and all others are "falsy".

    Now, we have a small set of "falsy" values and all others are "truthy" matching
    Ruby's semantics.

    *Rafael Mendonça França*

*   Deprecate `ActiveRecord::Base.errors_in_transactional_callbacks=`.

    *Rafael Mendonça França*

*   Change transaction callbacks to not swallow errors.

    Before this change any errors raised inside a transaction callback
    were getting rescued and printed in the logs.

    Now these errors are not rescued anymore and just bubble up, as the other callbacks.

    *Rafael Mendonça França*

*   Remove deprecated `sanitize_sql_hash_for_conditions`.

    *Rafael Mendonça França*

*   Remove deprecated `Reflection#source_macro`.

    *Rafael Mendonça França*

*   Remove deprecated `symbolized_base_class` and `symbolized_sti_name`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Base.disable_implicit_join_references=`.

    *Rafael Mendonça França*

*   Remove deprecated access to connection specification using a string accessor.

    Now all strings will be handled as a URL.

    *Rafael Mendonça França*

*   Change the default `null` value for `timestamps` to `false`.

    *Rafael Mendonça França*

*   Return an array of pools from `connection_pools`.

    *Rafael Mendonça França*

*   Return a null column from `column_for_attribute` when no column exists.

    *Rafael Mendonça França*

*   Remove deprecated `serialized_attributes`.

    *Rafael Mendonça França*

*   Remove deprecated automatic counter caches on `has_many :through`.

    *Rafael Mendonça França*

*   Change the way in which callback chains can be halted.

    The preferred method to halt a callback chain from now on is to explicitly
    `throw(:abort)`.
    In the past, returning `false` in an Active Record `before_` callback had the
    side effect of halting the callback chain.
    This is not recommended anymore and, depending on the value of the
    `config.active_support.halt_callback_chains_on_return_false` option, will
    either not work at all or display a deprecation warning.

    *claudiob*

*   Clear query cache on rollback.

    *Florian Weingarten*

*   Fix setting of foreign_key for through associations when building a new record.

    Fixes #12698.

    *Ivan Antropov*

*   Improve dumping of the primary key. If it is not a default primary key,
    correctly dump the type and options.

    Fixes #14169, #16599.

    *Ryuta Kamizono*

*   Format the datetime string according to the precision of the datetime field.

    Incompatible to rounding behavior between MySQL 5.6 and earlier.

    In 5.5, when you insert `2014-08-17 12:30:00.999999` the fractional part
    is ignored. In 5.6, it's rounded to `2014-08-17 12:30:01`:

    http://bugs.mysql.com/bug.php?id=68760

    *Ryuta Kamizono*

*   Allow a precision option for MySQL datetimes.

    *Ryuta Kamizono*

*   Fixed automatic `inverse_of` for models nested in a module.

    *Andrew McCloud*

*   Change `ActiveRecord::Relation#update` behavior so that it can
    be called without passing ids of the records to be updated.

    This change allows updating multiple records returned by
    `ActiveRecord::Relation` with callbacks and validations.

        # Before
        # ArgumentError: wrong number of arguments (1 for 2)
        Comment.where(group: 'expert').update(body: "Group of Rails Experts")

        # After
        # Comments with group expert updated with body "Group of Rails Experts"
        Comment.where(group: 'expert').update(body: "Group of Rails Experts")

    *Prathamesh Sonpatki*

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

*   `validates_size_of` / `validates_length_of` do not count records
    which are `marked_for_destruction?`.

    Fixes #7247.

    *Yves Senn*

*   Ensure `first!` and friends work on loaded associations.

    Fixes #18237.

    *Sean Griffin*

*   `eager_load` preserves readonly flag for associations.

    Closes #15853.

    *Takashi Kokubun*

*   Provide `:touch` option to `save()` to accommodate saving without updating
    timestamps.

    Fixes #18202.

    *Dan Olson*

*   Provide a more helpful error message when an unsupported class is passed to
    `serialize`.

    Fixes #18224.

    *Sean Griffin*

*   Add bigint primary key support for MySQL.

    Example:

        create_table :foos, id: :bigint do |t|
        end

    *Ryuta Kamizono*

*   Support for any type of primary key.

    Fixes #14194.

    *Ryuta Kamizono*

*   Dump the default `nil` for PostgreSQL UUID primary key.

    *Ryuta Kamizono*

*   Add a `:foreign_key` option to `references` and associated migration
    methods. The model and migration generators now use this option, rather than
    the `add_foreign_key` form.

    *Sean Griffin*

*   Don't raise when writing an attribute with an out-of-range datetime passed
    by the user.

    *Grey Baker*

*   Replace deprecated `ActiveRecord::Tasks::DatabaseTasks#load_schema` with
    `ActiveRecord::Tasks::DatabaseTasks#load_schema_for`.

    *Yves Senn*

*   Fix bug with `ActiveRecord::Type::Numeric` that caused negative values to
    be marked as having changed when set to the same negative value.

    Closes #18161.

    *Daniel Fox*

*   Introduce `force: :cascade` option for `create_table`. Using this option
    will recreate tables even if they have dependent objects (like foreign keys).
    `db/schema.rb` now uses `force: :cascade`. This makes it possible to
    reload the schema when foreign keys are in place.

    *Matthew Draper*, *Yves Senn*

*   `db:schema:load` and `db:structure:load` no longer purge the database
    before loading the schema. This is left for the user to do.
    `db:test:prepare` will still purge the database.

    Closes #17945.

    *Yves Senn*

*   Fix undesirable RangeError by `Type::Integer`. Add `Type::UnsignedInteger`.

    *Ryuta Kamizono*

*   Add `foreign_type` option to `has_one` and `has_many` association macros.

    This option enables to define the column name of associated object's type for polymorphic associations.

    *Ulisses Almeida*, *Kassio Borges*

*   Remove deprecated behavior allowing nested arrays to be passed as query
    values.

    *Melanie Gilman*

*   Deprecate passing a class as a value in a query. Users should pass strings
    instead.

    *Melanie Gilman*

*   `add_timestamps` and `remove_timestamps` now properly reversible with
    options.

    *Noam Gagliardi-Rabinovich*

*   `ActiveRecord::ConnectionAdapters::ColumnDumper#column_spec` and
    `ActiveRecord::ConnectionAdapters::ColumnDumper#prepare_column_options` no
    longer have a `types` argument. They should access
    `connection#native_database_types` directly.

    *Yves Senn*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/activerecord/CHANGELOG.md) for previous changes.
