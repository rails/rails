module ActiveModel
  module Type
    class Integer < Value # :nodoc:
      include Helpers::Numeric

      # Column storage size in bytes.
      # 4 bytes means a MySQL int or Postgres integer as opposed to smallint etc.
      DEFAULT_LIMIT = 4

      def initialize(*)
        super
        @range = min_value...max_value
      end

      def type
        :integer
      end

      def deserialize(value)
        return if value.nil?
        value.to_i
      end

      def serialize(value)
        result = cast(value)
        if result
          ensure_in_range(result)
        end
        result
      end

      # TODO Change this to private once we've dropped Ruby 2.2 support.
      # Workaround for Ruby 2.2 "private attribute?" warning.
      protected

        attr_reader :range

      private

        def cast_value(value)
          case value
          when true then 1
          when false then 0
          else
            value.to_i rescue nil
          end
        end

        def ensure_in_range(value)
          unless range.cover?(value)
            raise ActiveModel::RangeError, "#{value} is out of range for #{self.class} with limit #{_limit} bytes"
          end
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
