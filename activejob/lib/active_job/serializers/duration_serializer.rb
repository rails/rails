# frozen_string_literal: true

module ActiveJob
  module Serializers
    class DurationSerializer < ObjectSerializer # :nodoc:
      def serialize(duration)
        super("value" => duration.value, "parts" => Arguments.serialize(duration.parts))
      end

      def deserialize(hash)
        value = hash["value"]
        parts = Arguments.deserialize(hash["parts"])

        klass.new(value, parts)
      end

      private
        def klass
          ActiveSupport::Duration
        end
    end
  end
end
