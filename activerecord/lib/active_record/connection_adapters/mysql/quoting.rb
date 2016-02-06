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
