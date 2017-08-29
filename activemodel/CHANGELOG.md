*	Add alias key to as_json

	When I have 2 or more has_many associations, I want to use the second has_many association
	name with content of first has_many associations.

	Example:
	  user = User.last
	  user.as_json(include: { friends: { alias: :new_friends } }) # will produce:
	  {"email"=>"david@example.com", "gender"=>"male", "name"=>"David", "new_friends"=>[]}

    *Yoga Hapriana*

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
