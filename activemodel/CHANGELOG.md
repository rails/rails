## Rails 5.2.0.beta2 (November 28, 2017) ##

*  Return correct date while converting parameters in `value_from_multiparameter_assignment`
    for `ActiveModel::Type::Date`

    Before:

        Day.new({"day(1i)"=>"1", "day(2i)"=>"1", "day(3i)"=>"1"})
        => #<Day id: nil, day: "0001-01-03", created_at: nil, updated_at: nil>

    After:

        Day.new({"day(1i)"=>"1", "day(2i)"=>"1", "day(3i)"=>"1"})
        => #<Day id: nil, day: "0001-01-01", created_at: nil, updated_at: nil>

    Fixes #28521

    *Sayan Chakraborty*


## Rails 5.2.0.beta1 (November 27, 2017) ##

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
