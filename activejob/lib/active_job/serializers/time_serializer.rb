# frozen_string_literal: true

module ActiveJob
  module Serializers
    class TimeSerializer < ObjectSerializer # :nodoc:
      def serialize(time)
        super("value" => time.iso8601)
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
