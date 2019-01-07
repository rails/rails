# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module SchemaStatements # :nodoc:
        # Returns an array of indexes for the given table.
        def indexes(table_name)
          indexes = []
          current_index = nil
          execute_and_free("SHOW KEYS FROM #{quote_table_name(table_name)}", "SCHEMA") do |result|
            each_hash(result) do |row|
              if current_index != row[:Key_name]
                next if row[:Key_name] == "PRIMARY" # skip the primary key
                current_index = row[:Key_name]

                mysql_index_type = row[:Index_type].downcase.to_sym
                case mysql_index_type
                when :fulltext, :spatial
                  index_type = mysql_index_type
                when :btree, :hash
                  index_using = mysql_index_type
                end

                indexes << [
                  row[:Table],
                  row[:Key_name],
                  row[:Non_unique].to_i == 0,
                  [],
                  lengths: {},
                  orders: {},
                  type: index_type,
                  using: index_using,
                  comment: row[:Index_comment].presence
                ]
              end

              if row[:Expression]
                expression = row[:Expression]
                expression = +"(#{expression})" unless expression.start_with?("(")
                indexes.last[-2] << expression
                indexes.last[-1][:expressions] ||= {}
                indexes.last[-1][:expressions][expression] = expression
                indexes.last[-1][:orders][expression] = :desc if row[:Collation] == "D"
              else
                indexes.last[-2] << row[:Column_name]
                indexes.last[-1][:lengths][row[:Column_name]] = row[:Sub_part].to_i if row[:Sub_part]
                indexes.last[-1][:orders][row[:Column_name]] = :desc if row[:Collation] == "D"
              end
            end
          end

          indexes.map do |index|
            options = index.last

            if expressions = options.delete(:expressions)
              orders = options.delete(:orders)
              lengths = options.delete(:lengths)

              columns = index[-2].map { |name|
                [ name.to_sym, expressions[name] || +quote_column_name(name) ]
              }.to_h

              index[-2] = add_options_for_index_columns(
                columns, order: orders, length: lengths
              ).values.join(", ")
            end

            IndexDefinition.new(*index)
          end
        end

        def remove_column(table_name, column_name, type = nil, options = {})
          if foreign_key_exists?(table_name, column: column_name)
            remove_foreign_key(table_name, column: column_name)
          end
          super
        end

        def create_table(table_name, options: default_row_format, **)
          super
        end

        def internal_string_options_for_primary_key
          super.tap do |options|
            if !row_format_dynamic_by_default? && CHARSETS_OF_4BYTES_MAXLEN.include?(charset)
              options[:collation] = collation.sub(/\A[^_]+/, "utf8")
            end
          end
        end

        def update_table_definition(table_name, base)
          MySQL::Table.new(table_name, base)
        end

        def create_schema_dumper(options)
          MySQL::SchemaDumper.create(self, options)
        end

        private
          CHARSETS_OF_4BYTES_MAXLEN = ["utf8mb4", "utf16", "utf16le", "utf32"]

          def row_format_dynamic_by_default?
            if mariadb?
              version >= "10.2.2"
            else
              version >= "5.7.9"
            end
          end

          def default_row_format
            return if row_format_dynamic_by_default?

            unless defined?(@default_row_format)
              if query_value("SELECT @@innodb_file_per_table = 1 AND @@innodb_file_format = 'Barracuda'") == 1
                @default_row_format = "ROW_FORMAT=DYNAMIC"
              else
                @default_row_format = nil
              end
            end

            @default_row_format
          end

          def schema_creation
            MySQL::SchemaCreation.new(self)
          end

          def create_table_definition(*args)
            MySQL::TableDefinition.new(*args)
          end

          def new_column_from_field(table_name, field)
            type_metadata = fetch_type_metadata(field[:Type], field[:Extra])
            default, default_function = field[:Default], nil

            if type_metadata.type == :datetime && /\ACURRENT_TIMESTAMP(?:\([0-6]?\))?\z/i.match?(default)
              default, default_function = nil, default
            elsif type_metadata.extra == "DEFAULT_GENERATED"
              default = +"(#{default})" unless default.start_with?("(")
              default, default_function = nil, default
            end

            MySQL::Column.new(
              field[:Field],
              default,
              type_metadata,
              field[:Null] == "YES",
              table_name,
              default_function,
              field[:Collation],
              comment: field[:Comment].presence
            )
          end

          def fetch_type_metadata(sql_type, extra = "")
            MySQL::TypeMetadata.new(super(sql_type), extra: extra)
          end

          def extract_foreign_key_action(specifier)
            super unless specifier == "RESTRICT"
          end

          def add_index_length(quoted_columns, **options)
            lengths = options_for_index_columns(options[:length])
            quoted_columns.each do |name, column|
              column << "(#{lengths[name]})" if lengths[name].present?
            end
          end

          def add_options_for_index_columns(quoted_columns, **options)
            quoted_columns = add_index_length(quoted_columns, options)
            super
          end

          def data_source_sql(name = nil, type: nil)
            scope = quoted_scope(name, type: type)

            sql = +"SELECT table_name FROM information_schema.tables"
            sql << " WHERE table_schema = #{scope[:schema]}"
            sql << " AND table_name = #{scope[:name]}" if scope[:name]
            sql << " AND table_type = #{scope[:type]}" if scope[:type]
            sql
          end

          def quoted_scope(name = nil, type: nil)
            schema, name = extract_schema_qualified_name(name)
            scope = {}
            scope[:schema] = schema ? quote(schema) : "database()"
            scope[:name] = quote(name) if name
            scope[:type] = quote(type) if type
            scope
          end

          def extract_schema_qualified_name(string)
            schema, name = string.to_s.scan(/[^`.\s]+|`[^`]*`/)
            schema, name = nil, schema unless name
            [schema, name]
          end
      end
    end
  end
end
