# frozen_string_literal: true

module ActiveModel
  module Type
    # Attribute type for a collection of values. It is registered under
    # the +:collection+ key. +:element_type+ option is used to specify elements type
    #
    #   class User
    #     include ActiveModel::Attributes
    #
    #     attribute :lucky_numbers, :collection, element_type: :integer
    #   end
    #
    #   user = User.new(lucky_numbers: [1, 2, 3])
    #   user.lucky_numbers # => [1, 2, 3]
    #
    # Value is wrapped into an Array if not an Array already
    #
    #   User.new(lucky_numbers: 1).lucky_numbers # => [1]
    #
    # Collection elements are coerced by their +:element_type+ type
    #
    #   User.new(lucky_numbers: ["1"]).lucky_numbers # => [1]
    #
    class Collection < Value
      def initialize(**args)
        @element_type = args.delete(:element_type)
        @type_object = Type.lookup(element_type, **args)
        @serializer = args.delete(:serializer) || ActiveSupport::JSON
        super()
      end

      def type
        :collection
      end

      def cast(value)
        return [] if value.nil?
        Array(value).map { |el| @type_object.cast(el) }
      end

      def serializable?(value)
        value.all? { |el| @type_object.serializable?(el) }
      end

      def serialize(value)
        serializer.encode(value.map { |el| @type_object.serialize(el) })
      end

      def deserialize(value)
        serializer.decode(value).map { |el| @type_object.deserialize(el) }
      end

      def assert_valid_value(value)
        return if valid_value?(value)
        raise ArgumentError, "'#{value}' is not a valid #{type} of #{element_type}"
      end

      def changed_in_place?(raw_old_value, new_value)
        old_value = deserialize(raw_old_value)
        return true if old_value.size != new_value.size

        old_value.each_with_index.any? do |raw_old, i|
          @type_object.changed_in_place?(raw_old, new_value[i])
        end
      end

      def valid_value?(value)
        value.is_a?(Array) && value.all? { |el| @type_object.valid_value?(el) }
      end

      private
        attr_reader :element_type, :serializer
    end
  end
end
