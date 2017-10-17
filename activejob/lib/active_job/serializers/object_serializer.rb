# frozen_string_literal: true

module ActiveJob
  module Serializers
    class ObjectSerializer < BaseSerializer
      class << self
        def serialize(object)
          { key => object.class.name }
        end

        def deserialize?(argument)
          argument.respond_to?(:keys) && argument.keys == keys
        end

        def deserialize(hash)
          hash[key].constantize
        end

        private

        def keys
          [key]
        end
      end
    end
  end
end
