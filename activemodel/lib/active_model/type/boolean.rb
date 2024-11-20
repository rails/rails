# frozen_string_literal: true

module ActiveModel
  module Type
    # = Active Model \Boolean \Type
    #
    # A class that behaves like a boolean type, including rules for coercion of
    # user input.
    #
    # - <tt>"false"</tt>, <tt>"f"</tt>, <tt>"0"</tt>, +0+ or any other value in
    #   +FALSE_VALUES+ will be coerced to +false+.
    # - Empty strings are coerced to +nil+.
    # - All other values will be coerced to +true+.
    class Boolean < Value
      FALSE_VALUES = [
        false, 0,
        "0", :"0",
        "f", :f,
        "F", :F,
        "false", :false,
        "FALSE", :FALSE,
        "off", :off,
        "OFF", :OFF,
      ].to_set.freeze

      def type # :nodoc:
        :boolean
      end

      def serialize(value) # :nodoc:
        cast(value)
      end

      def serialize_cast_value(value) # :nodoc:
        value
      end

      private
        def cast_value(value)
          if value == ""
            nil
          else
            !FALSE_VALUES.include?(value)
          end
        end
    end
  end
end
