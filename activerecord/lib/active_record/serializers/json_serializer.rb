module ActiveRecord #:nodoc:
  module Serialization
    def self.included(base)
      base.cattr_accessor :include_root_in_json, :instance_writer => false
      base.extend ClassMethods
    end

    # Returns a JSON string representing the model. Some configuration is
    # available through +options+.
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
    def to_json(options = {})
      if include_root_in_json
        "{#{self.class.json_class_name}: #{JsonSerializer.new(self, options).to_s}}"
      else
        JsonSerializer.new(self, options).to_s
      end
    end

    def from_json(json)
      self.attributes = ActiveSupport::JSON.decode(json)
      self
    end

    class JsonSerializer < ActiveRecord::Serialization::Serializer #:nodoc:
      def serialize
        serializable_record.to_json
      end
    end

    module ClassMethods
      def json_class_name
        @json_class_name ||= name.demodulize.underscore.inspect
      end
    end
  end
end
