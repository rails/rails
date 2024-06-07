# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module Quoting # :nodoc:
        extend ActiveSupport::Concern

        QUOTED_COLUMN_NAMES = Concurrent::Map.new # :nodoc:
        QUOTED_TABLE_NAMES = Concurrent::Map.new # :nodoc:

        module ClassMethods # :nodoc:
          def column_name_matcher
            /
              \A
              (
                (?:
                  # "table_name"."column_name" | function(one or no argument)
                  ((?:\w+\.|"\w+"\.)?(?:\w+|"\w+") | \w+\((?:|\g<2>)\))
                )
                (?:(?:\s+AS)?\s+(?:\w+|"\w+"))?
              )
              (?:\s*,\s*\g<1>)*
              \z
            /ix
          end

          def column_name_with_order_matcher
            /
              \A
              (
                (?:
                  # "table_name"."column_name" | function(one or no argument)
                  ((?:\w+\.|"\w+"\.)?(?:\w+|"\w+") | \w+\((?:|\g<2>)\))
                )
                (?:\s+COLLATE\s+(?:\w+|"\w+"))?
                (?:\s+ASC|\s+DESC)?
              )
              (?:\s*,\s*\g<1>)*
              \z
            /ix
          end

          def quote_column_name(name)
            QUOTED_COLUMN_NAMES[name] ||= %Q("#{name.to_s.gsub('"', '""')}").freeze
          end

          def quote_table_name(name)
            QUOTED_TABLE_NAMES[name] ||= %Q("#{name.to_s.gsub('"', '""').gsub(".", "\".\"")}").freeze
          end
        end

        def quote_string(s)
          ::SQLite3::Database.quote(s)
        end

        def quote_table_name_for_assignment(table, attr)
          quote_column_name(attr)
        end

        def quoted_time(value)
          value = value.change(year: 2000, month: 1, day: 1)
          quoted_date(value).sub(/\A\d\d\d\d-\d\d-\d\d /, "2000-01-01 ")
        end

        def quoted_binary(value)
          "x'#{value.hex}'"
        end

        def quoted_true
          "1"
        end

        def unquoted_true
          1
        end

        def quoted_false
          "0"
        end

        def unquoted_false
          0
        end

        def quote_default_expression(value, column) # :nodoc:
          if value.is_a?(Proc)
            value = value.call
            if value.match?(/\A\w+\(.*\)\z/)
              "(#{value})"
            else
              value
            end
          else
            super
          end
        end

        def type_cast(value) # :nodoc:
          case value
          when BigDecimal, Rational
            value.to_f
          when String
            if value.encoding == Encoding::ASCII_8BIT
              super(value.encode(Encoding::UTF_8))
            else
              super
            end
          else
            super
          end
        end
      end
    end
  end
end
