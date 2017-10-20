# frozen_string_literal: true

module ActiveModel
  module Type
    # == Active \Model \Type \Boolean
    #
    # A class that behaves like a boolean type, including rules for coercion of user input.
    #
    # === Coercion
    # Values set from user input will first be coerced into the appropriate ruby type.
    # Coercion behavior is roughly mapped to Ruby's boolean semantics.
    #
    # - "false", "f" , "0", +0+ or any other value in +FALSE_VALUES+ will be coerced to +false+
    # - Empty strings are coerced to +nil+
    # - All other values will be coerced to +true+
    class Boolean < Value
      FALSE_VALUES = [false, 0, "0", "f", "F", "false", "FALSE", "off", "OFF"].to_set

      def type # :nodoc:
        :boolean
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
