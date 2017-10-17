# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Provides methods to serialize and deserialize `ActiveSupport::HashWithIndifferentAccess`
    # Values will be serialized by known serializers
    class HashWithIndifferentAccessSerializer < HashSerializer
      class << self
        def serialize(hash)
          result = serialize_hash(hash)
          result[key] = ::ActiveJob::Serializers.serialize(true)
          result
        end

        def deserialize?(argument)
          argument.is_a?(Hash) && argument[key]
        end

        def deserialize(hash)
          result = hash.transform_values { |v| ::ActiveJob::Serializers.deserialize(v) }
          result.delete(key)
          result.with_indifferent_access
        end

        def key
          "_aj_hash_with_indifferent_access"
        end

        private

        def klass
          ::ActiveSupport::HashWithIndifferentAccess
        end
      end
    end
  end
end
