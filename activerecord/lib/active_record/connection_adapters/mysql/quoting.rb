module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module Quoting # :nodoc:
        def quote_column_name(name)
          @quoted_column_names[name] ||= "`#{super.gsub('`', '``')}`"
        end

        def quote_table_name(name)
          @quoted_table_names[name] ||= super.gsub('.', '`.`')
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

        private

        QUOTED_TRUE, QUOTED_FALSE = '1', '0'

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
