module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module SchemaStatements
        # Drops the database specified on the +name+ attribute
        # and creates it again using the provided +options+.
        def recreate_database(name, options = {})
          drop_database(name)
          sql = create_database(name, options)
          reconnect!
          sql
        end

        # Create a new MySQL database with optional <tt>:charset</tt> and <tt>:collation</tt>.
        # Charset defaults to utf8.
        #
        # Example:
        #   create_database 'charset_test', charset: 'latin1', collation: 'latin1_bin'
        #   create_database 'matt_development'
        #   create_database 'matt_development', charset: :big5
        def create_database(name, options = {})
          if options[:collation]
            execute "CREATE DATABASE #{quote_table_name(name)} DEFAULT CHARACTER SET #{quote_table_name(options[:charset] || 'utf8')} COLLATE #{quote_table_name(options[:collation])}"
          else
            execute "CREATE DATABASE #{quote_table_name(name)} DEFAULT CHARACTER SET #{quote_table_name(options[:charset] || 'utf8')}"
          end
        end

        # Drops a MySQL database.
        #
        # Example:
        #   drop_database('sebastian_development')
        def drop_database(name) # :nodoc:
          execute "DROP DATABASE IF EXISTS #{quote_table_name(name)}"
        end

        def current_database
          select_value "SELECT DATABASE() as db"
        end

        # Returns the database character set.
        def charset
          show_variable "character_set_database"
        end

        # Returns the database collation strategy.
        def collation
          show_variable "collation_database"
        end

        def tables(name = nil) # :nodoc:
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            #tables currently returns both tables and views.
            This behavior is deprecated and will be changed with Rails 5.1 to only return tables.
            Use #data_sources instead.
          MSG

          if name
            ActiveSupport::Deprecation.warn(<<-MSG.squish)
              Passing arguments to #tables is deprecated without replacement.
            MSG
          end

          data_sources
        end

        def data_sources
          sql = "SELECT table_name FROM information_schema.tables "
          sql << "WHERE table_schema = #{quote(@config[:database])}"

          select_values(sql, "SCHEMA")
        end

        def truncate(table_name, name = nil)
          execute "TRUNCATE TABLE #{quote_table_name(table_name)}", name
        end

        def table_exists?(table_name)
          # Update lib/active_record/internal_metadata.rb when this gets removed
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            #table_exists? currently checks both tables and views.
            This behavior is deprecated and will be changed with Rails 5.1 to only check tables.
            Use #data_source_exists? instead.
          MSG

          data_source_exists?(table_name)
        end

        def data_source_exists?(table_name)
          return false unless table_name.present?

          schema, name = extract_schema_qualified_name(table_name)

          sql = "SELECT table_name FROM information_schema.tables "
          sql << "WHERE table_schema = #{quote(schema)} AND table_name = #{quote(name)}"

          select_values(sql, "SCHEMA").any?
        end

        def views # :nodoc:
          select_values("SHOW FULL TABLES WHERE table_type = 'VIEW'", "SCHEMA")
        end

        def view_exists?(view_name) # :nodoc:
          return false unless view_name.present?

          schema, name = extract_schema_qualified_name(view_name)

          sql = "SELECT table_name FROM information_schema.tables WHERE table_type = 'VIEW'"
          sql << " AND table_schema = #{quote(schema)} AND table_name = #{quote(name)}"

          select_values(sql, "SCHEMA").any?
        end

        INDEX_TYPES  = [:fulltext, :spatial]
        INDEX_USINGS = [:btree, :hash]

        # Returns an array of indexes for the given table.
        def indexes(table_name, name = nil) # :nodoc:
          indexes = []
          current_index = nil
          execute_and_free("SHOW KEYS FROM #{quote_table_name(table_name)}", "SCHEMA") do |result|
            each_hash(result) do |row|
              if current_index != row[:Key_name]
                next if row[:Key_name] == "PRIMARY" # skip the primary key
                current_index = row[:Key_name]

                mysql_index_type = row[:Index_type].downcase.to_sym
                index_type  = INDEX_TYPES.include?(mysql_index_type)  ? mysql_index_type : nil
                index_using = INDEX_USINGS.include?(mysql_index_type) ? mysql_index_type : nil
                indexes << IndexDefinition.new(row[:Table], row[:Key_name], row[:Non_unique].to_i == 0, [], {}, nil, nil, index_type, index_using, row[:Index_comment].presence)
              end

              indexes.last.columns << row[:Column_name]
              indexes.last.lengths.merge!(row[:Column_name] => row[:Sub_part].to_i) if row[:Sub_part]
            end
          end

          indexes
        end

        # Returns an array of +Column+ objects for the table specified by +table_name+.
        def columns(table_name) # :nodoc:
          table_name = table_name.to_s
          column_definitions(table_name).map do |field|
            type_metadata = fetch_type_metadata(field[:Type], field[:Extra])
            if type_metadata.type == :datetime && field[:Default] == "CURRENT_TIMESTAMP"
              default, default_function = nil, field[:Default]
            else
              default, default_function = field[:Default], nil
            end
            new_column(field[:Field], default, type_metadata, field[:Null] == "YES", table_name, default_function, field[:Collation], comment: field[:Comment].presence)
          end
        end

        def new_column(*args) # :nodoc:
          MySQL::Column.new(*args)
        end

        def table_comment(table_name) # :nodoc:
          schema, name = extract_schema_qualified_name(table_name)

          select_value(<<-SQL.strip_heredoc, "SCHEMA")
            SELECT table_comment
            FROM information_schema.tables
            WHERE table_schema = #{quote(schema)}
              AND table_name = #{quote(name)}
          SQL
        end

        def create_table(table_name, **options) # :nodoc:
          super(table_name, options: "ENGINE=InnoDB", **options)
        end

        def bulk_change_table(table_name, operations) # :nodoc:
          sqls = operations.flat_map do |command, args|
            table, arguments = args.shift, args
            method = :"#{command}_sql"

            if respond_to?(method, true)
              send(method, table, *arguments)
            else
              raise "Unknown method called : #{method}(#{arguments.inspect})"
            end
          end.join(", ")

          execute("ALTER TABLE #{quote_table_name(table_name)} #{sqls}")
        end

        # Renames a table.
        #
        # Example:
        #   rename_table('octopuses', 'octopi')
        def rename_table(table_name, new_name)
          execute "RENAME TABLE #{quote_table_name(table_name)} TO #{quote_table_name(new_name)}"
          rename_table_indexes(table_name, new_name)
        end

        # Drops a table from the database.
        #
        # [<tt>:force</tt>]
        #   Set to +:cascade+ to drop dependent objects as well.
        #   Defaults to false.
        # [<tt>:if_exists</tt>]
        #   Set to +true+ to only drop the table if it exists.
        #   Defaults to false.
        # [<tt>:temporary</tt>]
        #   Set to +true+ to drop temporary table.
        #   Defaults to false.
        #
        # Although this command ignores most +options+ and the block if one is given,
        # it can be helpful to provide these in a migration's +change+ method so it can be reverted.
        # In that case, +options+ and the block will be used by create_table.
        def drop_table(table_name, options = {})
          execute "DROP#{' TEMPORARY' if options[:temporary]} TABLE#{' IF EXISTS' if options[:if_exists]} #{quote_table_name(table_name)}#{' CASCADE' if options[:force] == :cascade}"
        end

        def rename_index(table_name, old_name, new_name)
          if supports_rename_index?
            validate_index_length!(table_name, new_name)

            execute "ALTER TABLE #{quote_table_name(table_name)} RENAME INDEX #{quote_table_name(old_name)} TO #{quote_table_name(new_name)}"
          else
            super
          end
        end

        def change_column_default(table_name, column_name, default_or_changes) # :nodoc:
          default = extract_new_default_value(default_or_changes)
          column = column_for(table_name, column_name)
          change_column table_name, column_name, column.sql_type, default: default
        end

        def change_column_null(table_name, column_name, null, default = nil) # :nodoc:
          column = column_for(table_name, column_name)

          unless null || default.nil?
            execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
          end

          change_column table_name, column_name, column.sql_type, null: null
        end

        def change_column(table_name, column_name, type, options = {}) # :nodoc:
          execute("ALTER TABLE #{quote_table_name(table_name)} #{change_column_sql(table_name, column_name, type, options)}")
        end

        def rename_column(table_name, column_name, new_column_name) # :nodoc:
          execute("ALTER TABLE #{quote_table_name(table_name)} #{rename_column_sql(table_name, column_name, new_column_name)}")
          rename_column_indexes(table_name, column_name, new_column_name)
        end

        def add_index(table_name, column_name, options = {}) # :nodoc:
          index_name, index_type, index_columns, _, index_algorithm, index_using, comment = add_index_options(table_name, column_name, options)
          sql = "CREATE #{index_type} INDEX #{quote_column_name(index_name)} #{index_using} ON #{quote_table_name(table_name)} (#{index_columns}) #{index_algorithm}"
          execute add_sql_comment!(sql, comment)
        end

        def add_sql_comment!(sql, comment) # :nodoc:
          sql << " COMMENT #{quote(comment)}" if comment.present?
          sql
        end

        def foreign_keys(table_name)
          raise ArgumentError unless table_name.present?

          schema, name = extract_schema_qualified_name(table_name)

          fk_info = select_all(<<-SQL.strip_heredoc, "SCHEMA")
            SELECT fk.referenced_table_name AS 'to_table',
                   fk.referenced_column_name AS 'primary_key',
                   fk.column_name AS 'column',
                   fk.constraint_name AS 'name',
                   rc.update_rule AS 'on_update',
                   rc.delete_rule AS 'on_delete'
            FROM information_schema.key_column_usage fk
            JOIN information_schema.referential_constraints rc
            USING (constraint_schema, constraint_name)
            WHERE fk.referenced_column_name IS NOT NULL
              AND fk.table_schema = #{quote(schema)}
              AND fk.table_name = #{quote(name)}
          SQL

          fk_info.map do |row|
            options = {
              column: row["column"],
              name: row["name"],
              primary_key: row["primary_key"]
            }

            options[:on_update] = extract_foreign_key_action(row["on_update"])
            options[:on_delete] = extract_foreign_key_action(row["on_delete"])

            ForeignKeyDefinition.new(table_name, row["to_table"], options)
          end
        end

        def table_options(table_name) # :nodoc:
          table_options = {}

          create_table_info = create_table_info(table_name)

          # strip create_definitions and partition_options
          raw_table_options = create_table_info.sub(/\A.*\n\) /m, "").sub(/\n\/\*!.*\*\/\n\z/m, "").strip

          # strip AUTO_INCREMENT
          raw_table_options.sub!(/(ENGINE=\w+)(?: AUTO_INCREMENT=\d+)/, '\1')

          table_options[:options] = raw_table_options

          # strip COMMENT
          if raw_table_options.sub!(/ COMMENT='.+'/, "")
            table_options[:comment] = table_comment(table_name)
          end

          table_options
        end

        # Maps logical Rails types to MySQL-specific data types.
        def type_to_sql(type, limit = nil, precision = nil, scale = nil, unsigned = nil)
          sql = \
            case type.to_s
            when "integer"
              integer_to_sql(limit)
            when "text"
              text_to_sql(limit)
            when "blob"
              binary_to_sql(limit)
            when "binary"
              if (0..0xfff) === limit
                "varbinary(#{limit})"
              else
                binary_to_sql(limit)
              end
            else
              super(type, limit, precision, scale)
            end

          sql << " unsigned" if unsigned && type != :primary_key
          sql
        end

        # SHOW VARIABLES LIKE 'name'
        def show_variable(name)
          select_value("SELECT @@#{name}", "SCHEMA")
        rescue ActiveRecord::StatementInvalid
          nil
        end

        def primary_keys(table_name) # :nodoc:
          raise ArgumentError unless table_name.present?

          schema, name = extract_schema_qualified_name(table_name)

          select_values(<<-SQL.strip_heredoc, "SCHEMA")
            SELECT column_name
            FROM information_schema.key_column_usage
            WHERE constraint_name = 'PRIMARY'
              AND table_schema = #{quote(schema)}
              AND table_name = #{quote(name)}
            ORDER BY ordinal_position
          SQL
        end

        # In MySQL 5.7.5 and up, ONLY_FULL_GROUP_BY affects handling of queries that use
        # DISTINCT and ORDER BY. It requires the ORDER BY columns in the select list for
        # distinct queries, and requires that the ORDER BY include the distinct column.
        # See https://dev.mysql.com/doc/refman/5.7/en/group-by-handling.html
        def columns_for_distinct(columns, orders) # :nodoc:
          order_columns = orders.reject(&:blank?).map { |s|
            # Convert Arel node to string
            s = s.to_sql unless s.is_a?(String)
            # Remove any ASC/DESC modifiers
            s.gsub(/\s+(?:ASC|DESC)\b/i, "")
          }.reject(&:blank?).map.with_index { |column, i| "#{column} AS alias_#{i}" }

          [super, *order_columns].join(", ")
        end

        protected

          def fetch_type_metadata(sql_type, extra = "")
            MySQL::TypeMetadata.new(super(sql_type), extra: extra)
          end

          def add_index_length(quoted_columns, **options)
            if length = options[:length]
              case length
              when Hash
                quoted_columns.each { |name, column| column << "(#{length[name]})" if length[name].present? }
              when Integer
                quoted_columns.each { |name, column| column << "(#{length})" }
              end
            end

            quoted_columns
          end

          def add_options_for_index_columns(quoted_columns, **options)
            quoted_columns = add_index_length(quoted_columns, options)
            super
          end

          def add_column_sql(table_name, column_name, type, options = {})
            td = create_table_definition(table_name)
            cd = td.new_column_definition(column_name, type, options)
            schema_creation.accept(AddColumnDefinition.new(cd))
          end

          def change_column_sql(table_name, column_name, type, options = {})
            column = column_for(table_name, column_name)

            unless options_include_default?(options)
              options[:default] = column.default
            end

            unless options.has_key?(:null)
              options[:null] = column.null
            end

            td = create_table_definition(table_name)
            cd = td.new_column_definition(column.name, type, options)
            schema_creation.accept(ChangeColumnDefinition.new(cd, column.name))
          end

          def rename_column_sql(table_name, column_name, new_column_name)
            column  = column_for(table_name, column_name)
            options = {
              default: column.default,
              null: column.null,
              auto_increment: column.auto_increment?
            }

            current_type = select_one("SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE '#{column_name}'", "SCHEMA")["Type"]
            td = create_table_definition(table_name)
            cd = td.new_column_definition(new_column_name, current_type, options)
            schema_creation.accept(ChangeColumnDefinition.new(cd, column.name))
          end

          def remove_column_sql(table_name, column_name, type = nil, options = {})
            "DROP #{quote_column_name(column_name)}"
          end

          def remove_columns_sql(table_name, *column_names)
            column_names.map { |column_name| remove_column_sql(table_name, column_name) }
          end

          def add_index_sql(table_name, column_name, options = {})
            index_name, index_type, index_columns, _, index_algorithm, index_using = add_index_options(table_name, column_name, options)
            index_algorithm[0, 0] = ", " if index_algorithm.present?
            "ADD #{index_type} INDEX #{quote_column_name(index_name)} #{index_using} (#{index_columns})#{index_algorithm}"
          end

          def remove_index_sql(table_name, options = {})
            index_name = index_name_for_remove(table_name, options)
            "DROP INDEX #{index_name}"
          end

          def add_timestamps_sql(table_name, options = {})
            [add_column_sql(table_name, :created_at, :datetime, options), add_column_sql(table_name, :updated_at, :datetime, options)]
          end

          def remove_timestamps_sql(table_name, options = {})
            [remove_column_sql(table_name, :updated_at), remove_column_sql(table_name, :created_at)]
          end

        private

          def column_definitions(table_name)
            execute_and_free("SHOW FULL FIELDS FROM #{quote_table_name(table_name)}", "SCHEMA") do |result|
              each_hash(result)
            end
          end

          def extract_foreign_key_action(specifier)
            case specifier
            when "CASCADE"; :cascade
            when "SET NULL"; :nullify
            end
          end

          def create_table_info(table_name)
            select_one("SHOW CREATE TABLE #{quote_table_name(table_name)}")["Create Table"]
          end

          def create_table_definition(*args)
            MySQL::TableDefinition.new(*args)
          end

          def extract_schema_qualified_name(string)
            schema, name = string.to_s.scan(/[^`.\s]+|`[^`]*`/)
            schema, name = @config[:database], schema unless name
            [schema, name]
          end

          def integer_to_sql(limit)
            case limit
            when 1; "tinyint"
            when 2; "smallint"
            when 3; "mediumint"
            when nil, 4; "int"
            when 5..8; "bigint"
            else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a decimal with scale 0 instead.")
            end
          end

          def text_to_sql(limit)
            case limit
            when 0..0xff;               "tinytext"
            when nil, 0x100..0xffff;    "text"
            when 0x10000..0xffffff;     "mediumtext"
            when 0x1000000..0xffffffff; "longtext"
            else raise(ActiveRecordError, "No text type has byte length #{limit}")
            end
          end

          def binary_to_sql(limit)
            case limit
            when 0..0xff;               "tinyblob"
            when nil, 0x100..0xffff;    "blob"
            when 0x10000..0xffffff;     "mediumblob"
            when 0x1000000..0xffffffff; "longblob"
            else raise(ActiveRecordError, "No binary type has byte length #{limit}")
            end
          end
      end
    end
  end
end
