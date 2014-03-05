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
