module ActiveJob
  module Serializers
    class DurationSerializer < ObjectSerializer
      class << self
        def serialize(duration)
          super("value" => duration.value, "parts" => Serializers.serialize(duration.parts))
        end

        def deserialize(hash)
          value = hash["value"]
          parts = Serializers.deserialize(hash["parts"])

          klass.new(value, parts)
        end

        private

        def klass
          ActiveSupport::Duration
        end
      end
    end
  end
end
