# frozen_string_literal: true

module ActiveJob
  module Serializers
    class DateSerializer < ObjectSerializer # :nodoc:
      def serialize(date)
        super("value" => date.iso8601)
      end

      def deserialize(hash)
        Date.iso8601(hash["value"])
      end

      private

        def klass
          Date
        end
    end
  end
end
