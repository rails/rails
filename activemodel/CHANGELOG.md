*   Add `json_key` option for attributes to customize serialization key names.

    ```ruby
    class Person
      include ActiveModel::Serializers::JSON
      include ActiveModel::Attributes

      attribute :first_name, json_key: "firstName"
    end

    person = Person.new(first_name: "John")
    person.as_json # => {"firstName"=>"John"}
    ```

    *heka1024*

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
