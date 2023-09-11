# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module SchemaStatements # :nodoc:
        # Returns an array of indexes for the given table.
        def indexes(table_name)
          internal_exec_query("PRAGMA index_list(#{quote_table_name(table_name)})", "SCHEMA").filter_map do |row|
            # Indexes SQLite creates implicitly for internal use start with "sqlite_".
            # See https://www.sqlite.org/fileformat2.html#intschema
            next if row["name"].start_with?("sqlite_")

            index_sql = query_value(<<~SQL, "SCHEMA")
              SELECT sql
              FROM sqlite_master
              WHERE name = #{quote(row['name'])} AND type = 'index'
              UNION ALL
              SELECT sql
              FROM sqlite_temp_master
              WHERE name = #{quote(row['name'])} AND type = 'index'
            SQL

            /\bON\b\s*"?(\w+?)"?\s*\((?<expressions>.+?)\)(?:\s*WHERE\b\s*(?<where>.+))?(?:\s*\/\*.*\*\/)?\z/i =~ index_sql

            columns = internal_exec_query("PRAGMA index_info(#{quote(row['name'])})", "SCHEMA").map do |col|
              col["name"]
            end

            orders = {}

            if columns.any?(&:nil?) # index created with an expression
              columns = expressions
            else
              # Add info on sort order for columns (only desc order is explicitly specified,
              # asc is the default)
              if index_sql # index_sql can be null in case of primary key indexes
                index_sql.scan(/"(\w+)" DESC/).flatten.each { |order_column|
                  orders[order_column] = :desc
                }
              end
            end

            IndexDefinition.new(
              table_name,
              row["name"],
              row["unique"] != 0,
              columns,
              where: where,
              orders: orders
            )
          end
        end

        def add_foreign_key(from_table, to_table, **options)
          alter_table(from_table) do |definition|
            to_table = strip_table_name_prefix_and_suffix(to_table)
            definition.foreign_key(to_table, **options)
          end
        end

        def remove_foreign_key(from_table, to_table = nil, **options)
          return if options.delete(:if_exists) == true && !foreign_key_exists?(from_table, to_table)

          to_table ||= options[:to_table]
          options = options.except(:name, :to_table, :validate)
          foreign_keys = foreign_keys(from_table)

          fkey = foreign_keys.detect do |fk|
            table = to_table || begin
              table = options[:column].to_s.delete_suffix("_id")
              Base.pluralize_table_names ? table.pluralize : table
            end
            table = strip_table_name_prefix_and_suffix(table)
            fk_to_table = strip_table_name_prefix_and_suffix(fk.to_table)
            fk_to_table == table && options.all? { |k, v| fk.options[k].to_s == v.to_s }
          end || raise(ArgumentError, "Table '#{from_table}' has no foreign key for #{to_table || options}")

          foreign_keys.delete(fkey)
          alter_table(from_table, foreign_keys)
        end

        def check_constraints(table_name)
          table_sql = query_value(<<-SQL, "SCHEMA")
            SELECT sql
            FROM sqlite_master
            WHERE name = #{quote(table_name)} AND type = 'table'
            UNION ALL
            SELECT sql
            FROM sqlite_temp_master
            WHERE name = #{quote(table_name)} AND type = 'table'
          SQL

          table_sql.to_s.scan(/CONSTRAINT\s+(?<name>\w+)\s+CHECK\s+\((?<expression>(:?[^()]|\(\g<expression>\))+)\)/i).map do |name, expression|
            CheckConstraintDefinition.new(table_name, expression, name: name)
          end
        end

        def add_check_constraint(table_name, expression, **options)
          alter_table(table_name) do |definition|
            definition.check_constraint(expression, **options)
          end
        end

        def remove_check_constraint(table_name, expression = nil, if_exists: false, **options)
          return if if_exists && !check_constraint_exists?(table_name, **options)

          check_constraints = check_constraints(table_name)
          chk_name_to_delete = check_constraint_for!(table_name, expression: expression, **options).name
          check_constraints.delete_if { |chk| chk.name == chk_name_to_delete }
          alter_table(table_name, foreign_keys(table_name), check_constraints)
        end

        def create_schema_dumper(options)
          SQLite3::SchemaDumper.create(self, options)
        end

        def schema_creation # :nodoc
          SQLite3::SchemaCreation.new(self)
        end

        private
          def valid_table_definition_options
            super + [:rename]
          end

          def create_table_definition(name, **options)
            SQLite3::TableDefinition.new(self, name, **options)
          end

          def validate_index_length!(table_name, new_name, internal = false)
            super unless internal
          end

          def new_column_from_field(table_name, field, definitions)
            default = field["dflt_value"]

            type_metadata = fetch_type_metadata(field["type"])
            default_value = extract_value_from_default(default)
            default_function = extract_default_function(default_value, default)
            rowid = is_column_the_rowid?(field, definitions)

            Column.new(
              field["name"],
              default_value,
              type_metadata,
              field["notnull"].to_i == 0,
              default_function,
              collation: field["collation"],
              auto_increment: field["auto_increment"],
              rowid: rowid
            )
          end

          INTEGER_REGEX = /integer/i
          # if a rowid table has a primary key that consists of a single column
          # and the declared type of that column is "INTEGER" in any mixture of upper and lower case,
          # then the column becomes an alias for the rowid.
          def is_column_the_rowid?(field, column_definitions)
            return false unless INTEGER_REGEX.match?(field["type"]) && field["pk"] == 1
            # is the primary key a single column?
            column_definitions.one? { |c| c["pk"] > 0 }
          end

          def data_source_sql(name = nil, type: nil)
            scope = quoted_scope(name, type: type)
            scope[:type] ||= "'table','view'"

            sql = +"SELECT name FROM sqlite_master WHERE name <> 'sqlite_sequence'"
            sql << " AND name = #{scope[:name]}" if scope[:name]
            sql << " AND type IN (#{scope[:type]})"
            sql
          end

          def quoted_scope(name = nil, type: nil)
            type = \
              case type
              when "BASE TABLE"
                "'table'"
              when "VIEW"
                "'view'"
              end
            scope = {}
            scope[:name] = quote(name) if name
            scope[:type] = type if type
            scope
          end
      end
    end
  end
end
