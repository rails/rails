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

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activemodel/CHANGELOG.md) for previous changes.
