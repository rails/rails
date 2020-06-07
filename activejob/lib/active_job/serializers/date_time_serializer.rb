# frozen_string_literal: true

module ActiveJob
  module Serializers
    class DateTimeSerializer < ObjectSerializer # :nodoc:
      def serialize(time)
        super("value" => time.iso8601)
      end

      def deserialize(hash)
        DateTime.iso8601(hash["value"])
      end

      private
        def klass
          DateTime
        end
    end
  end
end
