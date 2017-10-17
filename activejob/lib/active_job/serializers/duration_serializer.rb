# frozen_string_literal: true

module ActiveJob
  module Serializers
    # Provides methods to serialize and deserialize `ActiveSupport::Duration` (`1.day`, `2.weeks`, ...)
    class DurationSerializer < ObjectSerializer
      class << self
        def serialize(duration)
          {
            key => duration.value,
            parts_key => ::ActiveJob::Serializers.serialize(duration.parts)
          }
        end

        def deserialize(hash)
          value = hash[key]
          parts = ::ActiveJob::Serializers.deserialize(hash[parts_key])

          klass.new(value, parts)
        end

        def key
          "_aj_activesupport_duration"
        end

        private

        def klass
          ::ActiveSupport::Duration
        end

        def keys
          super.push parts_key
        end

        def parts_key
          "parts"
        end
      end
    end
  end
end
