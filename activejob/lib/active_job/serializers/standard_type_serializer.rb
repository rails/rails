# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Provides methods to serialize and deserialize standard types
    # (`NilClass`, `String`, `Integer`, `Fixnum`, `Bignum`, `Float`, `BigDecimal`, `TrueClass`, `FalseClass`)
    class StandardTypeSerializer < BaseSerializer # :nodoc:
      def serialize?(argument)
        Arguments::TYPE_WHITELIST.include? argument.class
      end

      def serialize(argument)
        argument
      end

      alias_method :deserialize?, :serialize?

      def deserialize(argument)
        object = GlobalID::Locator.locate(argument) if argument.is_a? String
        object || argument
      end
    end
  end
end
