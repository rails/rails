# frozen_string_literal: true

require "active_model/type/immutable_string"

module ActiveModel
  module Type
    # Attribute type for strings. It is registered under the +:string+ key.
    #
    # This class is a specialization of ActiveModel::Type::ImmutableString. It
    # performs coercion in the same way, and can be configured in the same way.
    # However, it accounts for mutable strings, so dirty tracking can properly
    # check if a string has changed.
    class String < ImmutableString
      def changed_in_place?(raw_old_value, new_value)
        if new_value.is_a?(::String)
          raw_old_value != new_value
        end
      end

      def to_immutable_string
        ImmutableString.new(
          true: @true,
          false: @false,
          limit: limit,
          precision: precision,
          scale: scale,
        )
      end

      private
        def cast_value(value)
          case value
          when ::String then ::String.new(value)
          when true then @true
          when false then @false
          else value.to_s
          end
        end
    end
  end
end
