# frozen_string_literal: true

module ActiveJob
  module Serializers
    class BaseSerializer
      include Singleton

      class << self
        delegate :serialize?, :deserialize?, :serialize, :deserialize, to: :instance
      end

      def serialize?(argument)
        argument.is_a?(klass)
      end

      def deserialize?(_argument)
        raise NotImplementedError
      end

      def serialize(_argument)
        raise NotImplementedError
      end

      def deserialize(_argument)
        raise NotImplementedError
      end

      protected

        def klass
          raise NotImplementedError
        end
    end
  end
end
