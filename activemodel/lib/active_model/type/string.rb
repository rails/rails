require "active_model/type/immutable_string"

module ActiveModel
  module Type
    class String < ImmutableString # :nodoc:
      def changed_in_place?(raw_old_value, new_value)
        if new_value.is_a?(::String)
          raw_old_value != new_value
        end
      end

      private

      def cast_value(value)
        ::String.new(super)
      end
    end
  end
end
