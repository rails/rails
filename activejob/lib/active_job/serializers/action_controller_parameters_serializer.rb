# frozen_string_literal: true

module ActiveJob
  module Serializers
    class ActionControllerParametersSerializer < ObjectSerializer
      def serialize(argument)
        Arguments.serialize_argument(argument.to_h.with_indifferent_access)
      end

      def deserialize(hash)
        raise NotImplementedError # Serialized as a HashWithIndifferentAccess
      end

      def serialize?(argument)
        argument.respond_to?(:permitted?) && argument.respond_to?(:to_h)
      end

      def klass
        if defined?(ActionController::Parameters)
          ActionController::Parameters
        end
      end
    end
  end
end
