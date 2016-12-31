module ActiveModel
  module Type
    class ImmutableString < Value # :nodoc:
      def type
        :string
      end

      def serialize(value)
        case value
        when ::Numeric, ActiveSupport::Duration then value.to_s
        when true then casted_true
        when false then casted_false
        else super
        end
      end

      private

        def cast_value(value)
          result = \
            case value
            when true then casted_true
            when false then casted_false
            else value.to_s
            end
          result.freeze
        end

        def casted_true
          "t".freeze
        end

        def casted_false
          "f".freeze
        end
    end
  end
end
