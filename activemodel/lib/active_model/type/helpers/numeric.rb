# frozen_string_literal: true

module ActiveModel
  module Type
    module Helpers # :nodoc: all
      module Numeric
        def serialize(value)
          cast(value)
        end

        def cast(value)
          # Checks whether the value is numeric. Spaceship operator
          # will return nil if value is not numeric.
          value = if value <=> 0
            value
          else
            case value
            when true then 1
            when false then 0
            else value.presence
            end
          end

          super(value)
        end

        def changed?(old_value, _new_value, new_value_before_type_cast) # :nodoc:
          return false if old_value.try(:nan?) && new_value_before_type_cast.try(:nan?)
          
          super || number_to_non_number?(old_value, new_value_before_type_cast)
        end

        private
          def number_to_non_number?(old_value, new_value_before_type_cast)
            old_value != nil && non_numeric_string?(new_value_before_type_cast.to_s)
          end

          def non_numeric_string?(value)
            # 'wibble'.to_i will give zero, we want to make sure
            # that we aren't marking int zero to string zero as
            # changed.
            !NUMERIC_REGEX.match?(value)
          end

          NUMERIC_REGEX = /\A\s*[+-]?\d/
          private_constant :NUMERIC_REGEX
      end
    end
  end
end
