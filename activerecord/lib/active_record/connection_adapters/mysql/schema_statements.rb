# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module SchemaStatements # :nodoc:
        # Returns an array of indexes for the given table.
        def indexes(table_name)
          indexes = []
          current_index = nil
          internal_exec_query("SHOW KEYS FROM #{quote_table_name(table_name)}", "SCHEMA").each do |row|
            if current_index != row["Key_name"]
              next if row["Key_name"] == "PRIMARY" # skip the primary key
              current_index = row["Key_name"]

              mysql_index_type = row["Index_type"].downcase.to_sym
              case mysql_index_type
              when :fulltext, :spatial
                index_type = mysql_index_type
              when :btree, :hash
                index_using = mysql_index_type
              end

              indexes << [
                row["Table"],
                row["Key_name"],
                row["Non_unique"].to_i == 0,
                [],
                lengths: {},
                orders: {},
                type: index_type,
                using: index_using,
                comment: row["Index_comment"].presence
              ]
            end

            if expression = row["Expression"]
              expression = expression.gsub("\\'", "'")
              expression = +"(#{expression})" unless expression.start_with?("(")
              indexes.last[-2] << expression
              indexes.last[-1][:expressions] ||= {}
              indexes.last[-1][:expressions][expression] = expression
              indexes.last[-1][:orders][expression] = :desc if row["Collation"] == "D"
            else
              indexes.last[-2] << row["Column_name"]
              indexes.last[-1][:lengths][row["Column_name"]] = row["Sub_part"].to_i if row["Sub_part"]
              indexes.last[-1][:orders][row["Column_name"]] = :desc if row["Collation"] == "D"
            end
          end

          indexes.map do |index|
            options = index.pop

            if expressions = options.delete(:expressions)
              orders = options.delete(:orders)
              lengths = options.delete(:lengths)

              columns = index[-1].to_h { |name|
                [ name.to_sym, expressions[name] || +quote_column_name(name) ]
              }

              index[-1] = add_options_for_index_columns(
                columns, order: orders, length: lengths
              ).values.join(", ")
            end

            IndexDefinition.new(*index, **options)
          end
        rescue StatementInvalid => e
          if e.message.match?(/Table '.+' doesn't exist/)
            []
          else
            raise
          end
        end

        def remove_column(table_name, column_name, type = nil, **options)
          if foreign_key_exists?(table_name, column: column_name)
            remove_foreign_key(table_name, column: column_name)
          end
          super
        end

        def create_table(table_name, options: default_row_format, **)
          super
        end

        def remove_foreign_key(from_table, to_table = nil, **options)
          # RESTRICT is by default in MySQL.
          options.delete(:on_update) if options[:on_update] == :restrict
          options.delete(:on_delete) if options[:on_delete] == :restrict
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

        # Maps logical Rails types to MySQL-specific data types.
        def type_to_sql(type, limit: nil, precision: nil, scale: nil, size: limit_to_size(limit, type), unsigned: nil, **)
          sql =
            case type.to_s
            when "integer"
              integer_to_sql(limit)
            when "text"
              type_with_size_to_sql("text", size)
            when "blob"
              type_with_size_to_sql("blob", size)
            when "binary"
              if (0..0xfff) === limit
                "varbinary(#{limit})"
              else
                type_with_size_to_sql("blob", size)
              end
            else
              super
            end

          sql = "#{sql} unsigned" if unsigned && type != :primary_key
          sql
        end

        def table_alias_length
          256 # https://dev.mysql.com/doc/refman/en/identifiers.html
        end

        def schema_creation # :nodoc:
          MySQL::SchemaCreation.new(self)
        end

        private
          CHARSETS_OF_4BYTES_MAXLEN = ["utf8mb4", "utf16", "utf16le", "utf32"]

          def row_format_dynamic_by_default?
            if mariadb?
              database_version >= "10.2.2"
            else
              database_version >= "5.7.9"
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

          def valid_primary_key_options
            super + [:unsigned, :auto_increment]
          end

          def create_table_definition(name, **options)
            MySQL::TableDefinition.new(self, name, **options)
          end

          def default_type(table_name, field_name)
            match = create_table_info(table_name)&.match(/`#{field_name}` (.+) DEFAULT ('|\d+|[A-z]+)/)
            default_pre = match[2] if match

            if default_pre == "'"
              :string
            elsif default_pre&.match?(/^\d+$/)
              :integer
            elsif default_pre&.match?(/^[A-z]+$/)
              :function
            end
          end

          def new_column_from_field(table_name, field, _definitions)
            field_name = field.fetch("COLUMN_NAME")

            type_metadata = fetch_type_metadata(field)

            default, default_function = field.fetch("COLUMN_DEFAULT"), nil

            if type_metadata.type == :datetime && /\ACURRENT_TIMESTAMP(?:\([0-6]?\))?\z/i.match?(default)
              default = "#{default} ON UPDATE #{default}" if /on update CURRENT_TIMESTAMP/i.match?(type_metadata.extra)
              default, default_function = nil, default
            elsif type_metadata.extra == "DEFAULT_GENERATED"
              default = +"(#{default})" unless default.start_with?("(")
              default = default.gsub("\\'", "'")
              default, default_function = nil, default
            elsif type_metadata.type == :text && default&.start_with?("'")
              # strip and unescape quotes
              default = default[1...-1].gsub("\\'", "'")
            elsif default&.match?(/\A\d/)
              # Its a number so we can skip the query to check if it is a function
            elsif default && default_type(table_name, field_name) == :function
              default, default_function = nil, default
            end

            MySQL::Column.new(
              field_name,
              default,
              type_metadata,
              field.fetch("IS_NULLABLE") == "YES",
              default_function,
              collation: field.fetch("COLLATION_NAME"),
              comment: field.fetch("COLUMN_COMMENT").presence
            )
          end

          def fetch_type_metadata(info)
            sql_type_metadata = begin
              numeric_precision = nil
              numeric_scale = nil

              if info.fetch("COLUMN_TYPE") =~ /\(.*\)/
                numeric_precision = info.fetch("NUMERIC_PRECISION")
                numeric_scale = info.fetch("NUMERIC_SCALE")
              end

              case info.fetch("DATA_TYPE")
              when "bigint"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :integer,
                  limit: 8,
                  precision: numeric_precision,
                  scale: numeric_scale,
                )
              when "int"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :integer,
                  limit: 4,
                  precision: numeric_precision,
                  scale: numeric_scale,
                )
              when "mediumint"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :integer,
                  limit: 3,
                  precision: numeric_precision,
                  scale: numeric_scale,
                )
              when "varchar"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :string,
                  limit: info.fetch("CHARACTER_MAXIMUM_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              when "datetime"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :datetime,
                  limit: nil,
                  precision: info.fetch("DATETIME_PRECISION"),
                  scale: nil,
                )
              when "text"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :text,
                  limit: info.fetch("CHARACTER_MAXIMUM_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              when "mediumtext"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :text,
                  limit: info.fetch("CHARACTER_MAXIMUM_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              when "tinytext"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :text,
                  limit: info.fetch("CHARACTER_MAXIMUM_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              when "longtext"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :text,
                  limit: info.fetch("CHARACTER_MAXIMUM_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              when "blob"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :binary,
                  limit: info.fetch("CHARACTER_OCTET_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              when "time"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :time,
                  limit: nil,
                  precision: info.fetch("DATETIME_PRECISION"),
                  scale: nil,
                )
              when "date"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :date,
                  limit: nil,
                  precision: info.fetch("DATETIME_PRECISION"),
                  scale: nil,
                )
              when "json"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :json,
                  limit: nil,
                  precision: nil,
                  scale: nil,
                )
              when "char"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :string,
                  limit: 1,
                  precision: nil,
                  scale: nil,
                )
              when "tinyblob"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :binary,
                  limit: info.fetch("CHARACTER_OCTET_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              when "mediumblob"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :binary,
                  limit: info.fetch("CHARACTER_OCTET_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              when "longblob"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :binary,
                  limit: info.fetch("CHARACTER_OCTET_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              when "tinyint"
                if self.class.emulate_booleans && info.fetch("COLUMN_TYPE") == "tinyint(1)"
                  SqlTypeMetadata.new(
                    sql_type: info.fetch("COLUMN_TYPE"),
                    type: :boolean,
                    limit: nil,
                    precision: nil,
                    scale: nil,
                  )
                else
                  SqlTypeMetadata.new(
                    sql_type: info.fetch("COLUMN_TYPE"),
                    type: :integer,
                    limit: 1,
                    precision: numeric_precision,
                    scale: numeric_scale,
                  )
                end
              when "timestamp"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :datetime,
                  limit: nil,
                  precision: info.fetch("DATETIME_PRECISION"),
                  scale: nil,
                )
              when "float"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :float,
                  limit: 24,
                  precision: numeric_precision,
                  scale: numeric_scale,
                )
              when "double"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :float,
                  limit: 53,
                  precision: numeric_precision,
                  scale: numeric_scale,
                )
              when "decimal"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :decimal,
                  limit: nil,
                  precision: numeric_precision,
                  scale: numeric_scale,
                )
              when "varbinary"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :binary,
                  limit: info.fetch("CHARACTER_OCTET_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              when "smallint"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :integer,
                  limit: 2,
                  precision: numeric_precision,
                  scale: numeric_scale,
                )
              when "set"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :string,
                  limit: nil, #info.fetch("CHARACTER_OCTET_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              when "enum"
                SqlTypeMetadata.new(
                  sql_type: info.fetch("COLUMN_TYPE"),
                  type: :string,
                  limit: nil, #info.fetch("CHARACTER_OCTET_LENGTH"),
                  precision: nil,
                  scale: nil,
                )
              else
                $stderr.puts "unknown type #{info.fetch("DATA_TYPE")}"
                pp THEIRS: orig.sql_type_metadata
                p info
                $stderr.puts "unknown type #{info.fetch("DATA_TYPE")}"
              end
            end
            MySQL::TypeMetadata.new(sql_type_metadata, extra: info["EXTRA"])
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
            quoted_columns = add_index_length(quoted_columns, **options)
            super
          end

          def data_source_sql(name = nil, type: nil)
            scope = quoted_scope(name, type: type)

            sql = +"SELECT table_name FROM information_schema.tables"
            sql << " WHERE table_schema = #{scope[:schema]}"

            if scope[:name]
              sql << " AND table_name = #{scope[:name]}"
              sql << " AND table_name IN (SELECT table_name FROM information_schema.tables WHERE table_schema = #{scope[:schema]})"
            end

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

          def type_with_size_to_sql(type, size)
            case size&.to_s
            when nil, "tiny", "medium", "long"
              "#{size}#{type}"
            else
              raise ArgumentError,
                "#{size.inspect} is invalid :size value. Only :tiny, :medium, and :long are allowed."
            end
          end

          def limit_to_size(limit, type)
            case type.to_s
            when "text", "blob", "binary"
              case limit
              when 0..0xff;               "tiny"
              when nil, 0x100..0xffff;    nil
              when 0x10000..0xffffff;     "medium"
              when 0x1000000..0xffffffff; "long"
              else raise ArgumentError, "No #{type} type has byte size #{limit}"
              end
            end
          end

          def integer_to_sql(limit)
            case limit
            when 1; "tinyint"
            when 2; "smallint"
            when 3; "mediumint"
            when nil, 4; "int"
            when 5..8; "bigint"
            else raise ArgumentError, "No integer type has byte size #{limit}. Use a decimal with scale 0 instead."
            end
          end
      end
    end
  end
end
