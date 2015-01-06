*   Fix accessing of fixtures having non-string labels like Fixnum.

    *Prathamesh Sonpatki*

*   Remove deprecated support to preload instance-dependent associations.

    *Yves Senn*

*   Remove deprecated support for PostgreSQL ranges with exclusive lower bounds.

    *Yves Senn*

*   Remove deprecation when modifying a relation with cached arel.
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
    In the past, returning `false` in an ActiveRecord `before_` callback had the
    side effect of halting the callback chain.
    This is not recommended anymore and, depending on the value of the
    `config.active_support.halt_callback_chains_on_return_false` option, will
    either not work at all or display a deprecation warning.

    *claudiob*

*   Clear query cache on rollback.

    *Florian Weingarten*

*   Fixed setting of foreign_key for through associations while building of new record.

    Fixes #12698.

    *Ivan Antropov*

*   Improve a dump of the primary key support. If it is not a default primary key,
    correctly dump the type and options.

    Fixes #14169, #16599.

    *Ryuta Kamizono*

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
