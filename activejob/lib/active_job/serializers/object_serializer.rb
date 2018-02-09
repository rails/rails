# frozen_string_literal: true

module ActiveJob
  module Serializers
    class ObjectSerializer < BaseSerializer
      class << self
        def serialize(hash)
          { OBJECT_SERIALIZER_KEY => self.name }.merge!(hash)
        end

        def deserialize?(argument)
          argument.is_a?(Hash) && argument[OBJECT_SERIALIZER_KEY] == self.name
        end
      end
    end
  end
end
