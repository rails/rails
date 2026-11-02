# frozen_string_literal: true

# :markup: markdown
require "date"

module ActiveJob
  module Serializers
    class DateTimeSerializer < TimeObjectSerializer # :nodoc:
      def deserialize(hash)
        DateTime.iso8601(hash["value"])
      end

      def klass
        DateTime
      end
    end
  end
end
