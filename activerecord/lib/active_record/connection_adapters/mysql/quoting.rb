module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module Quoting # :nodoc:
        def quote_column_name(name)
          @quoted_column_names[name] ||= "`#{super.gsub('`', '``')}`".freeze
        end

        def quote_table_name(name)
          @quoted_table_names[name] ||= super.gsub(".", "`.`").freeze
        end

        def quoted_true
          "'1'".freeze
        end

        def unquoted_true
          "1".freeze
        end

        def quoted_false
          "'0'".freeze
        end

        def unquoted_false
          "0".freeze
        end

        def quoted_date(value)
          if supports_datetime_with_precision?
            super
          else
            super.sub(/\.\d{6}\z/, "")
          end
        end

        def quoted_binary(value)
          "x'#{value.hex}'"
        end
      end
    end
  end
end
