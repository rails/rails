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
          result = case value
                   when true then "t"
                   when false then "f"
                   else value.to_s
                   end
          result.freeze
        end
    end
  end
end
