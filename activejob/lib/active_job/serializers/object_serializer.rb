# frozen_string_literal: true

require "singleton"

module ActiveJob
  module Serializers
    # Base class for serializing and deserializing custom objects.
    #
    # Example:
    #
    #   class MoneySerializer < ActiveJob::Serializers::ObjectSerializer
    #     def serialize(money)
    #       super("amount" => money.amount, "currency" => money.currency)
    #     end
    #
    #     def deserialize(hash)
    #       Money.new(hash["amount"], hash["currency"])
    #     end
    #
    #     def klass
    #       Money
    #     end
    #   end
    class ObjectSerializer
      include Singleton

      class << self
        delegate :serialize?, :serialize, :deserialize, to: :instance
      end

      def initialize
        super
        @template = { Arguments::OBJECT_SERIALIZER_KEY => self.class.name }.freeze
      end

      # Determines if an argument should be serialized by a serializer.
      def serialize?(argument)
        argument.is_a?(klass)
      end

      # Serializes an argument to a JSON primitive type.
      def serialize(hash)
        @template.merge(hash)
      end

      # Deserializes an argument from a JSON primitive type.
      def deserialize(hash)
        raise NotImplementedError, "#{self.class.name} should implement a public #deserialize(hash) method"
      end
    end
  end
end
