*   Migrate methods from `ActiveRecord::AttributeMethods`, `ActiveRecord::Attributes::Read` and `ActiveRecord::Attributes::Write` to Active Model

    ```ruby
    class Topic
      include ActiveModel::AttributeMethods

      attr_accessor :title

      alias_attribute :heading, :title
    end

    topic = Topic.new
    topic[:title] = "Hello Title"
    topic[:title] # => "Hello Title"

    topic.write_attribute(:title, "Hello Title Method")
    topic.read_attribute(:title) # => "Hello Title Method"

    topic[:heading] = "Hello Heading"
    topic[:heading] # => "Hello Heading"

    topic.write_attribute(:heading, "Hello Heading Method")
    topic.read_attribute(:heading) # => "Hello Heading Method"
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
