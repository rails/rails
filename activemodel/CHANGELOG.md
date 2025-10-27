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

*   Add error type support arguments to `ActiveModel::Errors#messages_for` and `ActiveModel::Errors#full_messages_for`

    ```ruby
    person = Person.create()
    person.errors.full_messages_for(:name, :invalid)
    # => ["Name is invalid"]

    person.errors.messages_for(:name, :invalid)
    # => ["is invalid"]
    ```

    *Eugene Bezludny*

*   Make `ActiveModel::Serializers::JSON#from_json` compatible with `#assign_attributes`

    *Sean Doyle*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activemodel/CHANGELOG.md) for previous changes.
