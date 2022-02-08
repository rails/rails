# frozen_string_literal: true

module ActiveModel
  module Type
    class Model < Value # :nodoc:
      def initialize(**args)
        @class_name = args.delete(:class_name)
        @serializer = args.delete(:serializer) || ActiveSupport::JSON
        super
      end

      def changed_in_place?(raw_old_value, value)
        old_value = deserialize(raw_old_value)
        old_value.attributes != value.attributes
      end

      def valid_value?(value)
        return valid_hash?(value) if value.is_a?(Hash)

        value.is_a?(klass)
      end

      def type
        :model
      end

      def serializable?(value)
        value.is_a?(klass)
      end

      def serialize(value)
        serializer.encode(value.attributes_for_database)
      end

      def deserialize(value)
        attributes = serializer.decode(value)
        klass.new(attributes)
      end

      private
        attr_reader :serializer

        def valid_hash?(value)
          value.keys.map(&:to_s).difference(klass.attribute_names).none?
        end

        def klass
          @_model_type_class ||= @class_name.constantize
        end

        def cast_value(value)
          case value
          when Hash
            klass.new(value)
          else
            klass.new(value.attributes)
          end
        end
    end
  end
end
