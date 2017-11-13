*   Record timezone in use when writing an attribute

    With the switch to casting on read rather than on write any
    attributes that are set inside of a `Time.use_zone` block don't
    reflect that timezone. Fix by recording the timezone in effect
    when the attribute is set and then using that timezone when type
    casting the attribute for reading.

    Fixes #28877.

    *Andrew White*

*   Execute `ConfirmationValidator` validation when `_confirmation`'s value is `false`.

    *bogdanvlviv*

*   Allow passing a Proc or Symbol to length validator options.

    *Matt Rohrer*

*   Add method `#merge!` for `ActiveModel::Errors`.

    *Jahfer Husain*

*   Fix regression in numericality validator when comparing Decimal and Float input
    values with more scale than the schema.

    *Bradley Priest*

*   Fix methods `#keys`, `#values` in `ActiveModel::Errors`.

    Change `#keys` to only return the keys that don't have empty messages.

    Change `#values` to only return the not empty values.

    Example:

        # Before
        person = Person.new
        person.errors.keys     # => []
        person.errors.values   # => []
        person.errors.messages # => {}
        person.errors[:name]   # => []
        person.errors.messages # => {:name => []}
        person.errors.keys     # => [:name]
        person.errors.values   # => [[]]

        # After
        person = Person.new
        person.errors.keys     # => []
        person.errors.values   # => []
        person.errors.messages # => {}
        person.errors[:name]   # => []
        person.errors.messages # => {:name => []}
        person.errors.keys     # => []
        person.errors.values   # => []

    *bogdanvlviv*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/activemodel/CHANGELOG.md) for previous changes.
