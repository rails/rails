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
        # * +attr_name+ - The name of the attribute to serialize.
        # * +class_name_or_coder+ - Optional. May be one of the following:
        #   * <em>default</em> - The attribute value will be serialized as YAML.
        #     The attribute value must respond to +to_yaml+.
        #   * +Array+ - The attribute value will be serialized as YAML, but an
        #     empty +Array+ will be serialized as +NULL+. The attribute value
        #     must be an +Array+.
        #   * +Hash+ - The attribute value will be serialized as YAML, but an
        #     empty +Hash+ will be serialized as +NULL+. The attribute value
        #     must be a +Hash+.
        #   * +JSON+ - The attribute value will be serialized as JSON. The
        #     attribute value must respond to +to_json+.
        #   * <em>custom coder</em> - The attribute value will be serialized
        #     using the coder's <tt>dump(value)</tt> method, and will be
        #     deserialized using the coder's <tt>load(string)</tt> method. The
        #     +dump+ method may return +nil+ to serialize the value as +NULL+.
        #
        # ==== Options
        #
        # * +:default+ - The default value to use when no value is provided. If
        #   this option is not passed, the previous default value (if any) will
        #   be used. Otherwise, the default will be +nil+.
        #
        # ==== Examples
        #
        # ===== Serialize the +preferences+ attribute using YAML
        #
        #   class User < ActiveRecord::Base
        #     serialize :preferences
        #   end
        #
        # ===== Serialize the +preferences+ attribute using JSON
        #
        #   class User < ActiveRecord::Base
        #     serialize :preferences, JSON
        #   end
        #
        # ===== Serialize the +preferences+ +Hash+ using YAML
        #
        #   class User < ActiveRecord::Base
        #     serialize :preferences, Hash
        #   end
        #
        # ===== Serialize the +preferences+ attribute using a custom coder
        #
        #   class Rot13JSON
        #     def self.rot13(string)
        #       string.tr("a-zA-Z", "n-za-mN-ZA-M")
        #     end
        #
        #     # Serializes an attribute value to a string that will be stored in the database.
        #     def self.dump(value)
        #       rot13(ActiveSupport::JSON.dump(value))
        #     end
        #
        #     # Deserializes a string from the database to an attribute value.
        #     def self.load(string)
        #       ActiveSupport::JSON.load(rot13(string))
        #     end
        #   end
        #
        #   class User < ActiveRecord::Base
        #     serialize :preferences, Rot13JSON
        #   end
        #
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

            cast_type = cast_type.subtype if Type::Serialized === cast_type
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
