*   Format the datetime string according to the precision of the datetime field.

    Incompatible to rounding behavior between MySQL 5.6 and earlier.

    In 5.5, when you insert `2014-08-17 12:30:00.999999` the fractional part
    is ignored. In 5.6, it's rounded to `2014-08-17 12:30:01`:

    http://bugs.mysql.com/bug.php?id=68760

    *Ryuta Kamizono*

*   Allow precision option for MySQL datetimes.

    *Ryuta Kamizono*

*   Fixed automatic inverse_of for models nested in module.

    *Andrew McCloud*

*   Change `ActiveRecord::Relation#update` behavior so that it can
    be called without passing ids of the records to be updated.

    This change allows to update multiple records returned by
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

*   When a table has a composite primary key, the `primary_key` method for
    SQLite3 and PostgreSQL adapters was only returning the first field of the key.
    Ensures that it will return nil instead, as Active Record doesn't support
    composite primary keys.

    Fixes #18070.

    *arthurnn*

*   `validates_size_of` / `validates_length_of` do not count records,
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

*   Support for any type primary key.

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

*   Fixes bug with 'ActiveRecord::Type::Numeric' that causes negative values to
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

    *Ulisses Almeida, Kassio Borges*

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
