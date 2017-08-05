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

            # Because money output is formatted according to the locale, there are two
            # cases to consider (note the decimal separators):
            #  (1) $12,345,678.12
            #  (2) $12.345.678,12
            # Negative values are represented as follows:
            #  (3) -$2.55
            #  (4) ($2.55)

            value = value.sub(/^\((.+)\)$/, '-\1') # (4)
            case value
            when /^-?\D+[\d,]+\.\d{2}$/  # (1)
              value.gsub!(/[^-\d.]/, "")
            when /^-?\D+[\d.]+,\d{2}$/  # (2)
              value.gsub!(/[^-\d,]/, "").sub!(/,/, ".")
            end

            super(value)
          end
        end
      end
    end
  end
end
