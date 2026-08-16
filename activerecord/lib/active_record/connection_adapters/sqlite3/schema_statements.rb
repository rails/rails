# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module SchemaStatements # :nodoc:
        # Returns an array of indexes for the given table.
        def indexes(table_name)
          result = fetch_indexes(Array(table_name).map(&:to_s))
          table_name.is_a?(Array) ? result : result[table_name.to_s]
        end

        def add_foreign_key(from_table, to_table, if_not_exists: false, **options)
          options = foreign_key_options(from_table, to_table, options)
          return if if_not_exists && foreign_key_exists?(from_table, to_table, **options.slice(:column, :primary_key))

          assert_valid_deferrable(options[:deferrable])

          alter_table(from_table) do |definition|
            to_table = strip_table_name_prefix_and_suffix(to_table)
            definition.foreign_key(to_table, **options)
          end
        end

        def remove_foreign_key(from_table, to_table = nil, **options)
          to_table ||= options[:to_table]
          return if options.delete(:if_exists) && !foreign_key_exists?(from_table, to_table, **options.slice(:column, :name))

          options = options.except(:to_table, :validate)
          fkey = foreign_key_for!(from_table, to_table: to_table, **options)

          foreign_keys = foreign_keys(from_table)
          foreign_keys.delete(fkey)
          alter_table(from_table, foreign_keys)
        end

        def virtual_table_exists?(table_name)
          query_values(data_source_sql(table_name, type: "VIRTUAL TABLE")).any?
        end

        def check_constraints(table_name)
          result = fetch_check_constraints(Array(table_name).map(&:to_s))
          table_name.is_a?(Array) ? result : result[table_name.to_s]
        end

        def add_check_constraint(table_name, expression, if_not_exists: false, **options)
          return if if_not_exists && check_constraint_exists?(table_name, expression: expression, **options)

          alter_table(table_name) do |definition|
            definition.check_constraint(expression, **options)
          end
        end

        def remove_check_constraint(table_name, expression = nil, if_exists: false, **options)
          return if if_exists && !check_constraint_exists?(table_name, expression: expression, **options)

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
          # sqlite_master lists the permanent objects in the database and
          # sqlite_temp_master the temporary ones.
          MASTER_CTE = <<~SQL
            WITH master AS (
              SELECT name, type, sql FROM sqlite_master
              UNION ALL
              SELECT name, type, sql FROM sqlite_temp_master
            )
          SQL

          def fetch_indexes(tables)
            return {} if tables.empty?

            rows = query_all(<<~SQL).group_by { |row| row["table_name"] }
              #{MASTER_CTE}
              SELECT m.name AS table_name, i.name, i."unique"
              FROM master m
              JOIN pragma_index_list(m.name) i
              WHERE m.type = 'table'
                AND m.name IN (#{quoted_table_names(tables)})
                AND i.name NOT GLOB 'sqlite_*'
            SQL

            details = index_details(rows.each_value.flat_map { |group| group.map { |row| row["name"] } })

            tables.index_with do |table_name|
              rows.fetch(table_name, []).map do |row|
                index_sql, columns = details[row["name"]] || [nil, []]

                build_index(table_name, row, index_sql, columns)
              end
            end
          end

          # The statement an index was created with says whether it is partial and how
          # its columns are ordered, and repeats once per column of the index.
          def index_details(names)
            return {} if names.empty?

            query_all(<<~SQL).group_by { |row| row["index_name"] }
              #{MASTER_CTE}
              SELECT m.name AS index_name, m.sql, i.name
              FROM master m
              JOIN pragma_index_info(m.name) i
              WHERE m.type = 'index'
                AND m.name IN (#{names.map { |name| quote(name) }.join(", ")})
              ORDER BY m.name, i.seqno
            SQL
              .transform_values { |group| [group.first["sql"], group.map { |row| row["name"] }] }
          end

          def build_index(table_name, row, index_sql, columns)
            /\bON\b\s*"?(\w+?)"?\s*\((?<expressions>.+?)\)(?:\s*WHERE\b\s*(?<where>.+?))?(?:\s*\/\*.*\*\/)?\s*\z/im =~ index_sql

            where = where.sub(/\s*\/\*.*\*\/\z/, "") if where
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

          def fetch_check_constraints(tables)
            structures = table_structures(tables)

            tables.index_with do |table_name|
              create_table_sql, = structures[table_name]

              create_table_sql.to_s.scan(/CONSTRAINT\s+(?<name>\w+)\s+CHECK\s+\((?<expression>(:?[^()]|\(\g<expression>\))+)\)/i).map do |name, expression|
                CheckConstraintDefinition.new(table_name, expression, name: name)
              end
            end
          end

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
            generated_type = extract_generated_type(field)

            if generated_type.present?
              default_function = default
            else
              default_function = extract_default_function(default_value, default)
            end

            rowid = is_column_the_rowid?(field, definitions)

            Column.new(
              field["name"],
              lookup_cast_type(field["type"]),
              default_value,
              type_metadata,
              field["notnull"].to_i == 0,
              default_function,
              collation: field["collation"],
              auto_increment: field["auto_increment"],
              rowid: rowid,
              generated_type: generated_type
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

            sql = +"SELECT name FROM pragma_table_list WHERE schema <> 'temp'"
            sql << " AND name NOT IN ('sqlite_sequence', 'sqlite_schema')"
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
              when "VIRTUAL TABLE"
                "'virtual'"
              end
            scope = {}
            scope[:name] = quote(name) if name
            scope[:type] = type if type
            scope
          end

          def assert_valid_deferrable(deferrable)
            return if !deferrable || %i(immediate deferred).include?(deferrable)

            raise ArgumentError, "deferrable must be `:immediate` or `:deferred`, got: `#{deferrable.inspect}`"
          end

          def extract_generated_type(field)
            case field["hidden"]
            when 2 then :virtual
            when 3 then :stored
            end
          end
      end
    end
  end
end
