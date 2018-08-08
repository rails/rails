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
        # If you have an attribute that needs to be saved to the database as an
        # object, and retrieved as the same object, then specify the name of that
        # attribute using this method and it will be handled automatically. The
        # serialization is done through YAML. If +class_name+ is specified, the
        # serialized object must be of that class on assignment and retrieval.
        # Otherwise SerializationTypeMismatch will be raised.
        #
        # Empty objects as <tt>{}</tt>, in the case of +Hash+, or <tt>[]</tt>, in the case of
        # +Array+, will always be persisted as null.
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
        # * +class_name_or_coder+ - Optional, a coder object, which responds to +.load+ and +.dump+
        #   or a class name that the object type should be equal to.
        #
        # ==== Example
        #
        #   # Serialize a preferences attribute.
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
        def serialize(attr_name, class_name_or_coder = Object)
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

          decorate_attribute_type(attr_name, :serialize) do |type|
            if type_incompatible_with_serialize?(type, class_name_or_coder)
              raise ColumnNotSerializableError.new(attr_name, type)
            end

            Type::Serialized.new(type, coder)
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
