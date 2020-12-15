# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    module Serialization
      extend ActiveSupport::Concern

      class ColumnNotSerializableError < StandardError
        def initialize(name, type)
          super <<~EOS
            Column `#{name}` of type #{type.class} does not support `serialize` feature.
            Usually it means that you are trying to use `serialize`
            on a column that already implements serialization natively.
          EOS
        end
      end

      module ClassMethods
        # If you have an attribute that needs to be saved to the database as a
        # serialized object, and retrieved by deserializing into the same object,
        # then specify the name of that attribute using this method and serialization
        # will be handled automatically.
        #
        # The serialization format may be YAML, JSON, or any custom format using a
        # custom coder class.
        #
        # === Serialization formats
        #
        #   serialize attr_name [, class_name_or_coder]
        #
        #                        |                           |  database storage   |
        #   class_name_or_coder  | attribute read/write type | serialized | NULL   |
        #   ---------------------+---------------------------+------------+--------+
        #     <not given>        | any value that supports   |    YAML    |        |
        #                        |   .to_yaml                |            |        |
        #                        |                           |            |        |
        #   Array                | Array **                  |    YAML    |  []    |
        #                        |                           |            |        |
        #   Hash                 | Hash **                   |    YAML    |  {}    |
        #                        |                           |            |        |
        #   JSON                 | any value that supports   |    JSON    |        |
        #                        |   .to_json                |            |        |
        #                        |                           |            |        |
        #   <custom coder class> | any value supported by    |   custom   | custom |
        #                        | the custom coder class    |            |        |
        #
        # ** If +class_name_or_coder+ is +Array+ or +Hash+, values retrieved will
        # always be of that type, and any value assigned must be of that type or
        # +SerializationTypeMismatch+ will be raised.
        #
        # ==== Custom coders
        # A custom coder class or module may be given. This must have +self.load+
        # and +self.dump+ class/module methods. <tt>self.dump(object)</tt> will be called
        # to serialize an object and should return the serialized value to be
        # stored in the database (+nil+ to store as +NULL+). <tt>self.load(string)</tt>
        # will be called to reverse the process and load (unserialize) from the
        # database.
        #
        # Keep in mind that database adapters handle certain serialization tasks
        # for you. For instance: +json+ and +jsonb+ types in PostgreSQL will be
        # converted between JSON object/array syntax and Ruby +Hash+ or +Array+
        # objects transparently. There is no need to use #serialize in this
        # case.
        #
        # For more complex cases, such as conversion to or from your application
        # domain objects, consider using the ActiveRecord::Attributes API.
        #
        # ==== Parameters
        #
        # * +attr_name+ - The field name that should be serialized.
        # * +class_name_or_coder+ - Optional, may be be +Array+ or +Hash+ or
        #                           +JSON+ or a custom coder class or module
        #                           which responds to +.load+ and
        #                           +.dump+. See table above.
        #
        # ==== Options
        #
        # +default+ The default value to use when no value is provided. If this option
        # is not passed, the previous default value (if any) will be used.
        # Otherwise, the default will be +nil+.
        #
        # ==== Example
        #
        #   # Serialize a preferences attribute using YAML coder.
        #   class User < ActiveRecord::Base
        #     serialize :preferences
        #   end
        #
        #   # Serialize preferences using JSON as coder.
        #   class User < ActiveRecord::Base
        #     serialize :preferences, JSON
        #   end
        #
        #   # Serialize preferences as Hash using YAML coder.
        #   class User < ActiveRecord::Base
        #     serialize :preferences, Hash
        #   end
        #
        #   # Serialize preferences using a custom coder.
        #   class Rot13JSON
        #     def self.rot13(string)
        #       string.tr("a-zA-Z", "n-za-mN-ZA-M")
        #     end
        #
        #     # returns serialized string that will be stored in the database
        #     def self.dump(object)
        #       ActiveSupport::JSON.encode(object).rot13
        #     end
        #
        #     # reverses the above, turning the serialized string from the database
        #     # back into its original value
        #     def self.load(string)
        #       ActiveSupport::JSON.decode(string.rot13)
        #     end
        #   end
        #
        #   class User < ActiveRecord::Base
        #     serialize :preferences, Rot13JSON
        #   end
        def serialize(attr_name, class_name_or_coder = Object, **options)
          # When ::JSON is used, force it to go through the Active Support JSON encoder
          # to ensure special objects (e.g. Active Record models) are dumped correctly
          # using the #as_json hook.
          coder = if class_name_or_coder == ::JSON
            Coders::JSON
          elsif [:load, :dump].all? { |x| class_name_or_coder.respond_to?(x) }
            class_name_or_coder
          else
            Coders::YAMLColumn.new(attr_name, class_name_or_coder)
          end

          attribute(attr_name, **options) do |cast_type|
            if type_incompatible_with_serialize?(cast_type, class_name_or_coder)
              raise ColumnNotSerializableError.new(attr_name, cast_type)
            end

            Type::Serialized.new(cast_type, coder)
          end
        end

        private
          def type_incompatible_with_serialize?(type, class_name)
            type.is_a?(ActiveRecord::Type::Json) && class_name == ::JSON ||
              type.respond_to?(:type_cast_array, true) && class_name == ::Array
          end
      end
    end
  end
end
