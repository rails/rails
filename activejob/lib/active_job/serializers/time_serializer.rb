# frozen_string_literal: true

module ActiveJob
  module Serializers
    class TimeSerializer < TimeObjectSerializer # :nodoc:
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
