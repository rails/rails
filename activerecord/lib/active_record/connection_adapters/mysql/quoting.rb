# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module Quoting # :nodoc:
        def quote_column_name(name)
          self.class.quoted_column_names[name] ||= "`#{super.gsub('`', '``')}`"
        end

        def quote_table_name(name)
          self.class.quoted_table_names[name] ||= super.gsub('.', '`.`').freeze
        end

        def unquoted_true
          1
        end

        def unquoted_false
          0
        end

        def quoted_date(value)
          if supports_datetime_with_precision?
            super
          else
            super.sub(/\.\d{6}\z/, '')
          end
        end

        def quoted_binary(value)
          "x'#{value.hex}'"
        end

        def column_name_matcher
          COLUMN_NAME
        end

        def column_name_with_order_matcher
          COLUMN_NAME_WITH_ORDER
        end

        COLUMN_NAME = /
          \A
          (
            (?:
              # `table_name`.`column_name` | function(one or no argument)
              ((?:\w+\.|`\w+`\.)?(?:\w+|`\w+`)) | \w+\((?:|\g<2>)\)
            )
            (?:(?:\s+AS)?\s+(?:\w+|`\w+`))?
          )
          (?:\s*,\s*\g<1>)*
          \z
        /ix

        COLUMN_NAME_WITH_ORDER = /
          \A
          (
            (?:
              # `table_name`.`column_name` | function(one or no argument)
              ((?:\w+\.|`\w+`\.)?(?:\w+|`\w+`)) | \w+\((?:|\g<2>)\)
            )
            (?:\s+ASC|\s+DESC)?
          )
          (?:\s*,\s*\g<1>)*
          \z
        /ix

        private_constant :COLUMN_NAME, :COLUMN_NAME_WITH_ORDER

        private
          def _type_cast(value)
            case value
            when Date, Time then value
            else super
            end
          end
      end
    end
  end
end
