# frozen_string_literal: true

module ActiveJob
  module Serializers
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
