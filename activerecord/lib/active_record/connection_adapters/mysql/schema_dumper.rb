module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module ColumnDumper # :nodoc:
        def prepare_column_options(column)
          spec = super
          spec[:unsigned] = "true" if column.unsigned?

          if supports_virtual_columns? && column.virtual?
            spec[:as] = extract_expression_for_virtual_column(column)
            spec[:stored] = "true" if /\b(?:STORED|PERSISTENT)\b/.match?(column.extra)
            spec = { type: schema_type(column).inspect }.merge!(spec)
          end

          spec
        end

        def migration_keys
          super + [:unsigned]
        end

        private

          def default_primary_key?(column)
            super && column.auto_increment? && !column.unsigned?
          end

          def explicit_primary_key_default?(column)
            column.type == :integer && !column.auto_increment?
          end

          def schema_type(column)
            case column.sql_type
            when /\Atimestamp\b/
              :timestamp
            when "tinyblob"
              :blob
            else
              super
            end
          end

          def schema_precision(column)
            super unless /\A(?:date)?time(?:stamp)?\b/.match?(column.sql_type) && column.precision == 0
          end

          def schema_collation(column)
            if column.collation && table_name = column.table_name
              @table_collation_cache ||= {}
              @table_collation_cache[table_name] ||= select_one("SHOW TABLE STATUS LIKE '#{table_name}'")["Collation"]
              column.collation.inspect if column.collation != @table_collation_cache[table_name]
            end
          end

          def extract_expression_for_virtual_column(column)
            if mariadb?
              create_table_info = create_table_info(column.table_name)
              if %r/#{quote_column_name(column.name)} #{Regexp.quote(column.sql_type)}(?: COLLATE \w+)? AS \((?<expression>.+?)\) #{column.extra}/ =~ create_table_info
                $~[:expression].inspect
              end
            else
              scope = quoted_scope(column.table_name)
              sql = "SELECT generation_expression FROM information_schema.columns" \
                    " WHERE table_schema = #{scope[:schema]}" \
                    "   AND table_name = #{scope[:name]}" \
                    "   AND column_name = #{quote(column.name)}"
              select_value(sql, "SCHEMA").inspect
            end
          end
      end
    end
  end
end
