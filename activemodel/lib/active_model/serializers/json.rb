require 'active_support/json'

module ActiveModel
  # == Active Model JSON Serializer
  module Serializers
    module JSON
      extend ActiveSupport::Concern
      include ActiveModel::Serialization

      included do
        extend ActiveModel::Naming

        class_attribute :include_root_in_json
        self.include_root_in_json = false
      end

      # Returns a hash representing the model. Some configuration can be
      # passed through +options+.
      #
      # The option <tt>include_root_in_json</tt> controls the top-level behavior
      # of +as_json+. If +true+, +as_json+ will emit a single root node named
      # after the object's type. The default value for <tt>include_root_in_json</tt>
      # option is +false+.
      #
      #   user = User.find(1)
      #   user.as_json
      #   # => { "id" => 1, "name" => "Konata Izumi", "age" => 16,
      #   #     "created_at" => "2006/08/01", "awesome" => true}
      #
      #   ActiveRecord::Base.include_root_in_json = true
      #
      #   user.as_json
      #   # => { "user" => { "id" => 1, "name" => "Konata Izumi", "age" => 16,
      #   #                  "created_at" => "2006/08/01", "awesome" => true } }
      #
      # This behavior can also be achieved by setting the <tt>:root</tt> option
      # to +true+ as in:
      #
      #   user = User.find(1)
      #   user.as_json(root: true)
      #   # => { "user" => { "id" => 1, "name" => "Konata Izumi", "age" => 16,
      #   #                  "created_at" => "2006/08/01", "awesome" => true } }
      #
      # Without any +options+, the returned Hash will include all the model's
      # attributes.
      #
      #   user = User.find(1)
      #   user.as_json
      #   # => { "id" => 1, "name" => "Konata Izumi", "age" => 16,
      #   #      "created_at" => "2006/08/01", "awesome" => true}
      #
      # The <tt>:only</tt> and <tt>:except</tt> options can be used to limit
      # the attributes included, and work similar to the +attributes+ method.
      #
      #   user.as_json(only: [:id, :name])
      #   # => { "id" => 1, "name" => "Konata Izumi" }
      #
      #   user.as_json(except: [:id, :created_at, :age])
      #   # => { "name" => "Konata Izumi", "awesome" => true }
      #
      # To include the result of some method calls on the model use <tt>:methods</tt>:
      #
      #   user.as_json(methods: :permalink)
      #   # => { "id" => 1, "name" => "Konata Izumi", "age" => 16,
      #   #      "created_at" => "2006/08/01", "awesome" => true,
      #   #      "permalink" => "1-konata-izumi" }
      #
      # To include associations use <tt>:include</tt>:
      #
      #   user.as_json(include: :posts)
      #   # => { "id" => 1, "name" => "Konata Izumi", "age" => 16,
      #   #      "created_at" => "2006/08/01", "awesome" => true,
      #   #      "posts" => [ { "id" => 1, "author_id" => 1, "title" => "Welcome to the weblog" },
      #   #                   { "id" => 2, "author_id" => 1, "title" => "So I was thinking" } ] }
      #
      # Second level and higher order associations work as well:
      #
      #   user.as_json(include: { posts: {
      #                              include: { comments: {
      #                                             only: :body } },
      #                              only: :title } })
      #   # => { "id" => 1, "name" => "Konata Izumi", "age" => 16,
      #   #      "created_at" => "2006/08/01", "awesome" => true,
      #   #      "posts" => [ { "comments" => [ { "body" => "1st post!" }, { "body" => "Second!" } ],
      #   #                     "title" => "Welcome to the weblog" },
      #   #                   { "comments" => [ { "body" => "Don't think too hard" } ],
      #   #                     "title" => "So I was thinking" } ] }
      def as_json(options = nil)
        root = if options && options.key?(:root)
          options[:root]
        else
          include_root_in_json
        end

        if root
          root = self.class.model_name.element if root == true
          { root => serializable_hash(options) }
        else
          serializable_hash(options)
        end
      end

      # Sets the model +attributes+ from a JSON string. Returns +self+.
      #
      #   class Person
      #     include ActiveModel::Serializers::JSON
      #
      #     attr_accessor :name, :age, :awesome
      #
      #     def attributes=(hash)
      #       hash.each do |key, value|
      #         instance_variable_set("@#{key}", value)
      #       end
      #     end
      #
      #     def attributes
      #       instance_values
      #     end
      #   end
      #
      #   json = { name: 'bob', age: 22, awesome:true }.to_json
      #   person = Person.new
      #   person.from_json(json) # => #<Person:0x007fec5e7a0088 @age=22, @awesome=true, @name="bob">
      #   person.name            # => "bob"
      #   person.age             # => 22
      #   person.awesome         # => true
      #
      # The default value for +include_root+ is +false+. You can change it to
      # +true+ if the given JSON string includes a single root node.
      #
      #   json = { person: { name: 'bob', age: 22, awesome:true } }.to_json
      #   person = Person.new
      #   person.from_json(json) # => #<Person:0x007fec5e7a0088 @age=22, @awesome=true, @name="bob">
      #   person.name            # => "bob"
      #   person.age             # => 22
      #   person.awesome         # => true
      def from_json(json, include_root=include_root_in_json)
        hash = ActiveSupport::JSON.decode(json)
        hash = hash.values.first if include_root
        self.attributes = hash
        self
      end
    end
  end
end
