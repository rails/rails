## Rails 5.2.1.rc1 (July 30, 2018) ##

*   No changes.


## Rails 5.2.0 (April 09, 2018) ##

*   Do not lose all multiple `:includes` with options in serialization.

    *Mike Mangino*

*   Models using the attributes API with a proc default can now be marshalled.

    Fixes #31216.

    *Sean Griffin*

*   Fix to working before/after validation callbacks on multiple contexts.

    *Yoshiyuki Hirano*

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
