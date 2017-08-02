# frozen_string_literal: true

module ActiveModel
  module Type
    class ImmutableString < Value # :nodoc:
      def type
        :string
      end

      def serialize(value)
        case value
        when ::Numeric, ActiveSupport::Duration then value.to_s
        else super
        end
      end

      private

        def cast_value(value)
          result = value.to_s
          result.freeze
        end
    end
  end
end
