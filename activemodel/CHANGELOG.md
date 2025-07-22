*   Migrate `ActiveRecord::AttributeAssignment` support for multiparameter attributes to Active Model

    ```ruby
    class Topic
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :last_read_on, :date
    end

    topic = Topic.new
    topic.attributes = {
      "last_read_on(1i)" => "2023",
      "last_read_on(2i)" => "10",
      "last_read_on(3i)" => "17"
    )
    topic.last_read_on == Date.new(2023, 10, 17) # => true
    ```

    *Sean Doyle*

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
