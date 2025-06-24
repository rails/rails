# frozen_string_literal: true

module ActiveJob
  module Serializers
    class TimeWithZoneSerializer < ObjectSerializer # :nodoc:
      NANO_PRECISION = 9

      def serialize(time_with_zone)
        super(
          "value" => time_with_zone.iso8601(NANO_PRECISION),
          "time_zone" => time_with_zone.time_zone.tzinfo.name
        )
      end

      def deserialize(hash)
        Time.iso8601(hash["value"]).in_time_zone(hash["time_zone"] || Time.zone)
      end

      private
        def klass
          ActiveSupport::TimeWithZone
        end
    end
  end
end
