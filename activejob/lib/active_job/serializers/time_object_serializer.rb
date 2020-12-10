# frozen_string_literal: true

module ActiveJob
  module Serializers
    class TimeObjectSerializer < ObjectSerializer # :nodoc:
      NANO_PRECISION = 9

      def serialize(time)
        super("value" => time.iso8601(NANO_PRECISION))
      end
    end
  end
end
