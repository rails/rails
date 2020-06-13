# frozen_string_literal: true

module ActiveModel
  module Type
    class ImmutableString < Value # :nodoc:
      def initialize(**args)
        @true  = -(args.delete(:true)&.to_s  || "t")
        @false = -(args.delete(:false)&.to_s || "f")
        super
      end

      def type
        :string
      end

      def serialize(value)
        case value
        when ::Numeric, ::Symbol, ActiveSupport::Duration then value.to_s
        when true then @true
        when false then @false
        else super
        end
      end

      private
        def cast_value(value)
          case value
          when true then @true
          when false then @false
          else value.to_s.freeze
          end
        end
    end
  end
end
