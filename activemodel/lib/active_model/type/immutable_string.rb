module ActiveModel
  module Type
    class ImmutableString < Value # :nodoc:
      def type
        :string
      end

      def serialize(value)
        case value
        when ::Numeric, ActiveSupport::Duration then value.to_s
        when true then "t"
        when false then "f"
        else super
        end
      end

      private

      def cast_value(value)
        case value
        when true then "t"
        when false then "f"
        else value.to_s.freeze
        end
      end
    end
  end
end
