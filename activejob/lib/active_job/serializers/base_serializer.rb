# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Implement the basic interface for Active Job arguments serializers.
    class BaseSerializer
      include Singleton

      class << self
        delegate :serialize?, :deserialize?, :serialize, :deserialize, to: :instance
      end

      # Determines if an argument should be serialized by a serializer.
      def serialize?(argument)
        argument.is_a?(klass)
      end

      # Determines if an argument should be deserialized by a serializer.
      def deserialize?(_argument)
        raise NotImplementedError
      end

      # Serializes an argument to a JSON primitive type.
      def serialize(_argument)
        raise NotImplementedError
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
