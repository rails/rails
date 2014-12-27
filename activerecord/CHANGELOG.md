*   Provide :touch option to save() to accommodate saving without updating
    timestamps.

    Fixes #18202

    *Dan Olson*

*   Provide a more helpful error message when an unsupported class is passed to
    `serialize`

    Fixes #18224

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
