*   Make possible to change `record_timestamps` inside Callbacks.

    *Tieg Zaharia*

*   Fixed error where .persisted? throws SystemStackError for an unsaved model with a
    custom primary key that didn't save due to validation error.

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

*   Save `has_one` association even if the record doesn't changed.

    Fixes #14407.

    *Rafael Mendonça França*

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

*   Passing an Active Record object to `find` is now deprecated.  Call `.id`
    on the object first.

*   Passing an Active Record object to `find` or `exists?` is now deprecated.
    Call `.id` on the object first.

*   Only use BINARY for MySQL case sensitive uniqueness check when column has a case insensitive collation.

    *Ryuta Kamizono*

*   Support for MySQL 5.6 fractional seconds.

    *arthurnn*, *Tatsuhiko Miyagawa*

*   Support for Postgres `citext` data type enabling case-insensitive where
    values without needing to wrap in UPPER/LOWER sql functions.

    *Troy Kruthoff*, *Lachlan Sylvester*

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

*   Fixed error with validation with enum fields for records where the
    value for any enum attribute is always evaluated as 0 during
    uniqueness validation.

    Fixes #14172.

    *Vilius Luneckas* *Ahmed AbouElhamayed*

*   `before_add` callbacks are fired before the record is saved on
    `has_and_belongs_to_many` assocations *and* on `has_many :through`
    associations.  Before this change, `before_add` callbacks would be fired
    before the record was saved on `has_and_belongs_to_many` associations, but
    *not* on `has_many :through` associations.

    Fixes #14144.

*   Fixed STI classes not defining an attribute method if there is a
    conflicting private method defined on its ancestors.

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
    is not defined) it will raise an ArgumentException for ranges with excluding
    beginnings.

    *Yves Senn*

*   Support for user created range types in PostgreSQL.

    *Yves Senn*

Please check [4-1-stable](https://github.com/rails/rails/blob/4-1-stable/activerecord/CHANGELOG.md) for previous changes.
