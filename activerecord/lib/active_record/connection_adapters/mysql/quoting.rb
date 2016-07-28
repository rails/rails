module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module Quoting # :nodoc:
        QUOTED_TRUE, QUOTED_FALSE = '1'.freeze, '0'.freeze

        def quote_column_name(name)
          @quoted_column_names[name] ||= "`#{super.gsub('`', '``')}`".freeze
        end

        def quote_table_name(name)
          @quoted_table_names[name] ||= super.gsub('.', '`.`').freeze
        end

        def quoted_true
          QUOTED_TRUE
        end

        def unquoted_true
          1
        end

        def quoted_false
          QUOTED_FALSE
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

        private

        def _quote(value)
          if value.is_a?(Type::Binary::Data)
            "x'#{value.hex}'"
          else
            super
          end
        end
      end
    end
  end
end
