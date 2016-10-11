module ActiveModel
  module Type
    class Integer < Value # :nodoc:
      include Helpers::Numeric

      def type
        :integer
      end

      def deserialize(value)
        return if value.nil?
        value.to_i
      end

      def serialize(value)
        cast(value)
      end

      private

        def cast_value(value)
          case value
          when true then 1
          when false then 0
          else
            value.to_i rescue nil
          end
        end
    end
  end
end
