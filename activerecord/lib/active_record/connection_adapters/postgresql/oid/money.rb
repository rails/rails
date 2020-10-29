# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        class Money < Type::Decimal # :nodoc:
          def type
            :money
          end

          def scale
            2
          end

          def cast_value(value)
            return value unless ::String === value

            # Because money output is formatted according to the locale, there are many
            # cases to consider (note the separators an units):
            #  (1) $12,345,678.12
            #  (2) $12.345.678,12
            #  (3) 12 345 678,12 Kč
            # Negative values are represented as follows:
            #  (4) -$2.55
            #  (5) ($2.55)
            value = value.sub(/^\((.+)\)$/, '-\1') # (5)

            number_with_sign_and_separators = value.gsub(/[^\-\.\,0-9]/, "")
            decimal_fragment = number_with_sign_and_separators.match(/([\,\.])(\d*)$/)

            value = if decimal_fragment.nil?
              number_with_sign_and_separators
            elsif decimal_fragment[1] == "." # (1)
              number_with_sign_and_separators.gsub(",", "")
            else # (2,3)
              number_with_sign_and_separators.gsub(".", "").gsub(",", ".")
            end

            super(value)
          end
        end
      end
    end
  end
end
