# frozen_string_literal: true

module ActiveModel
  module Type
    # = Active Model \Integer \Type
    #
    # Attribute type for integer representation. This type is registered under
    # the +:integer+ key.
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :age, :integer
    #   end
    #
    # Values are cast using their +to_i+ method, except for blank strings, which
    # are cast to +nil+. If a +to_i+ method is not defined or raises an error,
    # the value will be cast to +nil+.
    #
    #   person = Person.new
    #
    #   person.age = "18"
    #   person.age # => 18
    #
    #   person.age = ""
    #   person.age # => nil
    #
    #   person.age = :not_an_integer
    #   person.age # => nil (because Symbol does not define #to_i)
    #
    # Serialization also works under the same principle. Non-numeric strings are
    # serialized as +nil+, for example.
    #
    # Serialization also validates that the integer can be stored using a
    # limited number of bytes. If it cannot, an ActiveModel::RangeError will be
    # raised. The default limit is 4 bytes, and can be customized when declaring
    # an attribute:
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :age, :integer, limit: 6
    #   end
    class Integer < Value
      include Helpers::Numeric

      # Column storage size in bytes.
      # 4 bytes means an integer as opposed to smallint etc.
      DEFAULT_LIMIT = 4

      def initialize(**)
        super
        @max = max_value
        @min = min_value
      end

      def type
        :integer
      end

      def deserialize(value)
        return if value.blank?
        value.to_i
      end

      def serialize(value)
        case value
        when ::Integer
          # noop
        when ::String
          int = value.to_i
          if int.zero? && value != "0"
            return if non_numeric_string?(value)
          end
          value = int
        else
          value = super
        end

        if out_of_range?(value)
          raise ActiveModel::RangeError, "#{value} is out of range for #{self.class} with limit #{_limit} bytes"
        end

        value
      end

      def serialize_cast_value(value) # :nodoc:
        if out_of_range?(value)
          raise ActiveModel::RangeError, "#{value} is out of range for #{self.class} with limit #{_limit} bytes"
        end

        value
      end

      def serializable?(value)
        cast_value = cast(value)
        return true unless out_of_range?(cast_value)
        yield cast_value if block_given?
        false
      end

      private
        def out_of_range?(value)
          value && (@max <= value || @min > value)
        end

        def cast_value(value)
          value.to_i rescue nil
        end

        def max_value
          1 << (_limit * 8 - 1) # 8 bits per byte with one bit for sign
        end

        def min_value
          -max_value
        end

        def _limit
          limit || DEFAULT_LIMIT
        end
    end
  end
end
