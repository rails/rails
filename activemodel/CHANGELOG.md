*   Add `ActiveModel::Type::Array` for handling array attributes.

    This new type allows model attributes to store arrays with optional element type casting.

    ```ruby
    class Person
      include ActiveModel::Attributes

      attribute :tags, :array
      attribute :counts, :array, of: :integer
      attribute :ratings, :array, of: :decimal, precision: 2
    end

    person = Person.new
    person.tags = ["ruby", "rails"]
    person.counts = ["1", "2", "3"] # => [1, 2, 3]
    person.ratings = ["3.5", "4.0"] # => [3.5, 4.0]

    # JSON string assignment is also supported
    person.counts = "[4, 5, 6]" # => [4, 5, 6]
    ```

    *Zakaria Fatahi*

*   Add `except_on:` option for validation callbacks.

    *Ben Sheldon*

*   Backport `ActiveRecord::Normalization` to `ActiveModel::Attributes::Normalization`

    ```ruby
    class User
      include ActiveModel::Attributes
      include ActiveModel::Attributes::Normalization

      attribute :email, :string

      normalizes :email, with: -> email { email.strip.downcase }
    end

    user = User.new
    user.email =    " CRUISE-CONTROL@EXAMPLE.COM\n"
    user.email # => "cruise-control@example.com"
    ```

    *Sean Doyle*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activemodel/CHANGELOG.md) for previous changes.
