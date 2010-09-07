require 'active_support/json'
require 'active_support/core_ext/class/attribute'

module ActiveModel
  # == Active Model JSON Serializer
  module Serializers
    module JSON
      extend ActiveSupport::Concern
      include ActiveModel::Serialization

      included do
        extend ActiveModel::Naming

        class_attribute :include_root_in_json
        self.include_root_in_json = true
      end

      # Returns a JSON string representing the model. Some configuration can be
      # passed through +options+.
      #
      # The option <tt>ActiveModel::Base.include_root_in_json</tt> controls the
      # top-level behavior of <tt>to_json</tt>. It is <tt>true</tt> by default. When it is <tt>true</tt>,
      # <tt>to_json</tt> will emit a single root node named after the object's type. For example:
      #
      #   konata = User.find(1)
      #   konata.to_json
      #   # => { "user": {"id": 1, "name": "Konata Izumi", "age": 16,
      #                   "created_at": "2006/08/01", "awesome": true} }
      #
      #   ActiveRecord::Base.include_root_in_json = false
      #   konata.to_json
      #   # => {"id": 1, "name": "Konata Izumi", "age": 16,
      #         "created_at": "2006/08/01", "awesome": true}
      #
      # The remainder of the examples in this section assume include_root_in_json is set to
      # <tt>false</tt>.
      #
      # Without any +options+, the returned JSON string will include all
      # the model's attributes. For example:
      #
      #   konata = User.find(1)
      #   konata.to_json
      #   # => {"id": 1, "name": "Konata Izumi", "age": 16,
      #         "created_at": "2006/08/01", "awesome": true}
      #
      # The <tt>:only</tt> and <tt>:except</tt> options can be used to limit the attributes
      # included, and work similar to the +attributes+ method. For example:
      #
      #   konata.to_json(:only => [ :id, :name ])
      #   # => {"id": 1, "name": "Konata Izumi"}
      #
      #   konata.to_json(:except => [ :id, :created_at, :age ])
      #   # => {"name": "Konata Izumi", "awesome": true}
      #
      # To include any methods on the model, use <tt>:methods</tt>.
      #
      #   konata.to_json(:methods => :permalink)
      #   # => {"id": 1, "name": "Konata Izumi", "age": 16,
      #         "created_at": "2006/08/01", "awesome": true,
      #         "permalink": "1-konata-izumi"}
      #
      # To include associations, use <tt>:include</tt>.
      #
      #   konata.to_json(:include => :posts)
      #   # => {"id": 1, "name": "Konata Izumi", "age": 16,
      #         "created_at": "2006/08/01", "awesome": true,
      #         "posts": [{"id": 1, "author_id": 1, "title": "Welcome to the weblog"},
      #                   {"id": 2, author_id: 1, "title": "So I was thinking"}]}
      #
      # 2nd level and higher order associations work as well:
      #
      #   konata.to_json(:include => { :posts => {
      #                                  :include => { :comments => {
      #                                                :only => :body } },
      #                                  :only => :title } })
      #   # => {"id": 1, "name": "Konata Izumi", "age": 16,
      #         "created_at": "2006/08/01", "awesome": true,
      #         "posts": [{"comments": [{"body": "1st post!"}, {"body": "Second!"}],
      #                    "title": "Welcome to the weblog"},
      #                   {"comments": [{"body": "Don't think too hard"}],
      #                    "title": "So I was thinking"}]}

      def as_json(options = nil)
        hash = serializable_hash(options)

        if include_root_in_json
          custom_root = options && options[:root]
          hash = { custom_root || self.class.model_name.element => hash }
        end

        hash
      end

      def from_json(json)
        hash = ActiveSupport::JSON.decode(json)
        hash = hash.values.first if include_root_in_json
        self.attributes = hash
        self
      end
    end
  end
end
