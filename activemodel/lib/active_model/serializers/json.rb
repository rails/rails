require 'active_support/json'
require 'active_support/core_ext/class/attribute_accessors'

module ActiveModel
  module Serializers
    module JSON
      extend ActiveSupport::Concern

      included do
        extend ActiveModel::Naming

        cattr_accessor :include_root_in_json, :instance_writer => false
      end

      class Serializer < ActiveModel::Serializer
        def serializable_hash
          model = super
          @serializable.include_root_in_json ?
            { @serializable.class.model_name.element => model } :
            model
        end

        def serialize
          ActiveSupport::JSON.encode(serializable_hash)
        end
      end

      # Returns a JSON string representing the model. Some configuration is
      # available through +options+.
      #
      # The option <tt>ActiveRecord::Base.include_root_in_json</tt> controls the
      # top-level behavior of to_json. In a new Rails application, it is set to 
      # <tt>true</tt> in initializers/new_rails_defaults.rb. When it is <tt>true</tt>,
      # to_json will emit a single root node named after the object's type. For example:
      #
      #   konata = User.find(1)
      #   ActiveRecord::Base.include_root_in_json = true
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
      def encode_json(encoder)
        Serializer.new(self, encoder.options).to_s
      end

      def as_json(options = nil)
        self
      end

      def from_json(json)
        self.attributes = ActiveSupport::JSON.decode(json)
        self
      end
    end
  end
end
