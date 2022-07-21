# frozen_string_literal: true

require "bigdecimal"

module ActiveJob
  module Serializers
    class BigDecimalSerializer < ObjectSerializer # :nodoc:
      def serialize(big_decimal)
        super("value" => big_decimal.to_s)
      end

      def deserialize(hash)
        BigDecimal(hash["value"])
      end

      private
        def klass
          BigDecimal
        end
    end
  end
end
