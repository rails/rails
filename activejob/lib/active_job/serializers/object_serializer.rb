# frozen_string_literal: true

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
    #     private
    #
    #       def klass
    #         Money
    #       end
    #   end
    class ObjectSerializer
      include Singleton

      class << self
        delegate :serialize?, :serialize, :deserialize, to: :instance
      end

      # Determines if an argument should be serialized by a serializer.
      def serialize?(argument)
        argument.is_a?(klass)
      end

      # Serializes an argument to a JSON primitive type.
      def serialize(hash)
        { Arguments::OBJECT_SERIALIZER_KEY => self.class.name }.merge!(hash)
      end

      # Deserializes an argument from a JSON primitive type.
      def deserialize(json)
        raise NotImplementedError
      end

      private
        # The class of the object that will be serialized.
        def klass # :doc:
          raise NotImplementedError
        end
    end
  end
end
