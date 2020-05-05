# frozen_string_literal: true

module ActiveModel
  module Type
    class Integer < Value # :nodoc:
      include Helpers::Numeric

      # Column storage size in bytes.
      # 4 bytes means an integer as opposed to smallint etc.
      DEFAULT_LIMIT = 4

      def initialize(**)
        super
        @range = min_value...max_value
      end

      def type
        :integer
      end

      def deserialize(value)
        return if value.blank?
        value.to_i
      end

      def serialize(value)
        return if value.is_a?(::String) && non_numeric_string?(value)
        return unless serializable?(value)
        super
      end

      def serializable?(value)
        cast_value = cast(value)
        in_range?(cast_value) && super
      end

      private
        attr_reader :range

        def in_range?(value)
          !value || range.member?(value)
        end

        def cast_value(value)
          value.to_i rescue nil
        end

        def max_value
          1 << (_limit * 8 - 1) # 8 bits per byte with one bit for sign
        end

        def min_value
          -max_value
        end

        def _limit
          limit || DEFAULT_LIMIT
        end
    end
  end
end
