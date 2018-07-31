# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module Quoting # :nodoc:
        def quote_string(s)
          @connection.class.quote(s)
        end

        def quote_table_name_for_assignment(table, attr)
          quote_column_name(attr)
        end

        def quote_column_name(name)
          @quoted_column_names[name] ||= %Q("#{super.gsub('"', '""')}").freeze
        end

        def quoted_time(value)
          value = value.change(year: 2000, month: 1, day: 1)
          quoted_date(value).sub(/\A\d\d\d\d-\d\d-\d\d /, "2000-01-01 ")
        end

        def quoted_binary(value)
          "x'#{value.hex}'"
        end

        def quoted_true
          ActiveRecord::ConnectionAdapters::SQLite3Adapter.represent_boolean_as_integer ? "1".freeze : "'t'".freeze
        end

        def unquoted_true
          ActiveRecord::ConnectionAdapters::SQLite3Adapter.represent_boolean_as_integer ? 1 : "t".freeze
        end

        def quoted_false
          ActiveRecord::ConnectionAdapters::SQLite3Adapter.represent_boolean_as_integer ? "0".freeze : "'f'".freeze
        end

        def unquoted_false
          ActiveRecord::ConnectionAdapters::SQLite3Adapter.represent_boolean_as_integer ? 0 : "f".freeze
        end

        private

          def _type_cast(value)
            case value
            when BigDecimal
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
