# frozen_string_literal: true

module ActiveJob
  module Serializers
    class DurationSerializer < ObjectSerializer # :nodoc:
      def serialize(duration)
        # Ideally duration.parts would be wrapped in an array before passing to Arguments.serialize,
        # but we continue passing the bare hash for backwards compatibility:
        super("value" => duration.value, "parts" => Arguments.serialize(duration.parts))
      end

      def deserialize(hash)
        value = hash["value"]
        parts = Arguments.deserialize(hash["parts"])
        # `parts` is originally a hash, but will have been flattened to an array by Arguments.serialize
        klass.new(value, parts.to_h)
      end

      private
        def klass
          ActiveSupport::Duration
        end
    end
  end
end
