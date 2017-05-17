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
