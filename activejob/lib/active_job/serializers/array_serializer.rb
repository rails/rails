# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Provides methods to serialize and deserialize `Array`
    class ArraySerializer < BaseSerializer
      class << self
        alias_method :deserialize?, :serialize?

        def serialize(array)
          array.map { |arg| Serializers.serialize(arg) }
        end

        def deserialize(array)
          array.map { |arg| Serializers.deserialize(arg) }
        end

        private

        def klass
          Array
        end
      end
    end
  end
end
