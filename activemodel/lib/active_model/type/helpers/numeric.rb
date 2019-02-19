# frozen_string_literal: true

module ActiveModel
  module Type
    module Helpers # :nodoc: all
      module Numeric
        def cast(value)
          value = \
            case value
            when true then 1
            when false then 0
            when ::String then value.presence
            else value
            end
          super(value)
        end

        def changed?(old_value, _new_value, new_value_before_type_cast) # :nodoc:
          super || number_to_non_number?(old_value, new_value_before_type_cast)
        end

        private

          def number_to_non_number?(old_value, new_value_before_type_cast)
            old_value != nil && non_numeric_string?(new_value_before_type_cast)
          end

          def non_numeric_string?(value)
            # 'wibble'.to_i will give zero, we want to make sure
            # that we aren't marking int zero to string zero as
            # changed.
            !/\A[-+]?\d+/.match?(value.to_s)
          end
      end
    end
  end
end
