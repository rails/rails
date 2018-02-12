# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Base class for serializing and deserializing custom times.
    #
    # Example
    #
    #     class MoneySerializer < ActiveJob::Serializers::ObjectSerializer
    #       def serialize(money)
    #         super("cents" => money.cents, "currency" => money.currency)
    #       end
    #
    #       def deserialize(hash)
    #         Money.new(hash["cents"], hash["currency"])
    #       end
    #
    #       private
    #
    #         def klass
    #           Money
    #         end
    #     end
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

      # Deserilizes an argument form a JSON primiteve type.
      def deserialize(_argument)
        raise NotImplementedError
      end

      protected

        # The class of the object that will be serialized.
        def klass
          raise NotImplementedError
        end
    end
  end
end
