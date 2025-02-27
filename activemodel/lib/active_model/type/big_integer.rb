# frozen_string_literal: true

require "active_model/type/integer"

module ActiveModel
  module Type
    # = Active Model \BigInteger \Type
    #
    # Attribute type for integers that can be serialized to an unlimited number
    # of bytes. This type is registered under the +:big_integer+ key.
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :id, :big_integer
    #   end
    #
    #   person = Person.new
    #   person.id = "18_000_000_000"
    #
    #   person.id # => 18000000000
    #
    # All casting and serialization are performed in the same way as the
    # standard ActiveModel::Type::Integer type.
    class BigInteger < Integer
      def serialize(value) # :nodoc:
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

        value
      end

      def serialize_cast_value(value) # :nodoc:
        value
      end

      def serializable?(value, &)
        true
      end

      private
        def max_value
          ::Float::INFINITY
        end
    end
  end
end
