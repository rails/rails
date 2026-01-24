# frozen_string_literal: true

require "active_support/time_with_zone"

module ActiveRecord
  module ConnectionAdapters
    module MySQL
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
                  # `table_name`.`column_name` | function(one or no argument)
                  ((?:\w+\.|`\w+`\.)?(?:\w+|`\w+`) | \w+\((?:|\g<2>)\))
                )
                (?:(?:\s+AS)?\s+(?:\w+|`\w+`))?
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
                  # `table_name`.`column_name` | function(one or no argument)
                  ((?:\w+\.|`\w+`\.)?(?:\w+|`\w+`) | \w+\((?:|\g<2>)\))
                )
                (?:\s+COLLATE\s+(?:\w+|"\w+"))?
                (?:\s+ASC|\s+DESC)?
              )
              (?:\s*,\s*\g<1>)*
              \z
            /ix
          end

          def quote_column_name(name)
            QUOTED_COLUMN_NAMES[name] ||= "`#{name.to_s.gsub('`', '``')}`".freeze
          end

          def quote_table_name(name)
            QUOTED_TABLE_NAMES[name] ||= "`#{name.to_s.gsub('`', '``').gsub(".", "`.`")}`".freeze
          end
        end

        def cast_bound_value(value)
          case value
          when Rational
            value.to_f.to_s
          when Numeric
            value.to_s
          when BigDecimal
            value.to_s("F")
          when true
            "1"
          when false
            "0"
          else
            value
          end
        end

        def unquoted_true
          1
        end

        def unquoted_false
          0
        end

        def quoted_binary(value)
          "x'#{value.hex}'"
        end

        def unquote_identifier(identifier)
          if identifier && identifier.start_with?("`")
            identifier[1..-2]
          else
            identifier
          end
        end

        # Override +type_cast+ we pass to mysql2 Date and Time objects instead
        # of Strings since MySQL adapters are able to handle those classes more efficiently.
        def type_cast(value) # :nodoc:
          case value
          when ActiveSupport::TimeWithZone
            # We need to check explicitly for ActiveSupport::TimeWithZone because
            # we need to transform it to Time objects but we don't want to
            # transform Time objects to themselves.
            if default_timezone == :utc
              value.getutc
            else
              value.getlocal
            end
          when Time
            if default_timezone == :utc
              value.utc? ? value : value.getutc
            else
              value.utc? ? value.getlocal : value
            end
          when Date
            value
          else
            super
          end
        end
      end
    end
  end
end
