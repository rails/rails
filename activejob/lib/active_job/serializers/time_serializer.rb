# frozen_string_literal: true

module ActiveJob
  module Serializers
    class TimeSerializer < ObjectSerializer # :nodoc:
      def serialize(time)
        super("value" => time.iso8601(ActiveJob::Serializers.time_precision))
      end

      def deserialize(hash)
        Time.iso8601(hash["value"])
      end

      private
        def klass
          Time
        end
    end
  end
end
