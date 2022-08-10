# frozen_string_literal: true

module ActiveModel
  module Type
    # Attribute type for representation of binary data. This type is registered
    # under the +:binary+ key.
    #
    # Non-string values are coerced to strings using their +to_s+ method.
    class Binary < Value
      def type
        :binary
      end

      def binary?
        true
      end

      def cast(value)
        if value.is_a?(Data)
          value.to_s
        else
          super
        end
      end

      def serialize(value)
        return if value.nil?
        Data.new(super)
      end

      def changed_in_place?(raw_old_value, value)
        old_value = deserialize(raw_old_value)
        old_value != value
      end

      class Data # :nodoc:
        def initialize(value)
          @value = value.to_s
        end

        def to_s
          @value
        end
        alias_method :to_str, :to_s

        def hex
          @value.unpack1("H*")
        end

        def ==(other)
          other == to_s || super
        end
      end
    end
  end
end
