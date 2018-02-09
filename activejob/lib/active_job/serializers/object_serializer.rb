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
    class ObjectSerializer < BaseSerializer
      def serialize(hash)
        { OBJECT_SERIALIZER_KEY => self.class.name }.merge!(hash)
      end

      def deserialize?(argument)
        argument.is_a?(Hash) && argument[OBJECT_SERIALIZER_KEY] == self.class.name
      end
    end
  end
end
