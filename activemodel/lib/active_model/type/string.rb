# frozen_string_literal: true

require "active_model/type/immutable_string"

module ActiveModel
  module Type
    class String < ImmutableString # :nodoc:
      def changed_in_place?(raw_old_value, new_value)
        if new_value.is_a?(::String)
          raw_old_value != new_value
        end
      end

      def to_immutable_string
        ImmutableString.new(
          limit: limit,
          precision: precision,
          scale: scale,
        )
      end

      private
        def cast_value(value)
          case value
          when ::String then ::String.new(value)
          when true then "t"
          when false then "f"
          else value.to_s
          end
        end
    end
  end
end
