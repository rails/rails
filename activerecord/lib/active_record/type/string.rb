module ActiveRecord
  module Type
    class String < Value # :nodoc:
      def type
        :string
      end

      def text?
        true
      end

      def changed_in_place?(raw_old_value, new_value)
        if new_value.is_a?(::String)
          raw_old_value != new_value
        end
      end

      def type_cast_for_database(value)
        if value.is_a?(::String)
          ::String.new(value)
        else
          super
        end
      end

      private

      def cast_value(value)
        case value
        when true then "1"
        when false then "0"
        # String.new is slightly faster than dup
        else ::String.new(value.to_s)
        end
      end
    end
  end
end
