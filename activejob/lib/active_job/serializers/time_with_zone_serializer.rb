# frozen_string_literal: true

module ActiveJob
  module Serializers
    class TimeWithZoneSerializer < TimeObjectSerializer # :nodoc:
      def deserialize(hash)
        Time.iso8601(hash["value"]).in_time_zone
      end

      private
        def klass
          ActiveSupport::TimeWithZone
        end
    end
  end
end
