require 'active_support/core_ext/string/strip'

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class SchemaCreation < AbstractAdapter::SchemaCreation
        private

        def visit_ColumnDefinition(o)
          o.sql_type = type_to_sql(o.type, o.limit, o.precision, o.scale, o.array)
          super
        end

        def add_column_options!(sql, options)
          if options[:collation]
            sql << " COLLATE \"#{options[:collation]}\""
          end
          super
        end
      end

      module SchemaStatements
        # Drops the database specified on the +name+ attribute
        # and creates it again using the provided +options+.
        def recreate_database(name, options = {}) #:nodoc:
          drop_database(name)
          create_database(name, options)
        end

        # Create a new PostgreSQL database. Options include <tt>:owner</tt>, <tt>:template</tt>,
        # <tt>:encoding</tt> (defaults to utf8), <tt>:collation</tt>, <tt>:ctype</tt>,
        # <tt>:tablespace</tt>, and <tt>:connection_limit</tt> (note that MySQL uses
        # <tt>:charset</tt> while PostgreSQL uses <tt>:encoding</tt>).
        #
        # Example:
        #   create_database config[:database], config
        #   create_database 'foo_development', encoding: 'unicode'
        def create_database(name, options = {})
          options = { encoding: 'utf8' }.merge!(options.symbolize_keys)

          option_string = options.inject("") do |memo, (key, value)|
            memo += case key
            when :owner
              " OWNER = \"#{value}\""
            when :template
              " TEMPLATE = \"#{value}\""
            when :encoding
              " ENCODING = '#{value}'"
            when :collation
              " LC_COLLATE = '#{value}'"
            when :ctype
              " LC_CTYPE = '#{value}'"
            when :tablespace
              " TABLESPACE = \"#{value}\""
            when :connection_limit
              " CONNECTION LIMIT = #{value}"
            else
              ""
            end
          end

          execute "CREATE DATABASE #{quote_table_name(name)}#{option_string}"
        end

        # Drops a PostgreSQL database.
        #
        # Example:
        #   drop_database 'matt_development'
        def drop_database(name) #:nodoc:
          execute "DROP DATABASE IF EXISTS #{quote_table_name(name)}"
        end

        # Returns the list of all tables in the schema search path.
        def tables(name = nil)
          if name
            ActiveSupport::Deprecation.warn(<<-MSG.squish)
              Passing arguments to #tables is deprecated without replacement.
            MSG
          end

          select_values("SELECT tablename FROM pg_tables WHERE schemaname = ANY(current_schemas(false))", 'SCHEMA')
        end

        def data_sources # :nodoc
          select_values(<<-SQL, 'SCHEMA')
            SELECT c.relname
            FROM pg_class c
            LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relkind IN ('r', 'v','m') -- (r)elation/table, (v)iew, (m)aterialized view
            AND n.nspname = ANY (current_schemas(false))
          SQL
        end

        # Returns true if table exists.
        # If the schema is not specified as part of +name+ then it will only find tables within
        # the current schema search path (regardless of permissions to access tables in other schemas)
        def table_exists?(name)
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            #table_exists? currently checks both tables and views.
            This behavior is deprecated and will be changed with Rails 5.1 to only check tables.
            Use #data_source_exists? instead.
          MSG

          data_source_exists?(name)
        end

        def data_source_exists?(name)
          name = Utils.extract_schema_qualified_name(name.to_s)
          return false unless name.identifier

          select_value(<<-SQL, 'SCHEMA').to_i > 0
              SELECT COUNT(*)
              FROM pg_class c
              LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE c.relkind IN ('r','v','m') -- (r)elation/table, (v)iew, (m)aterialized view
              AND c.relname = '#{name.identifier}'
              AND n.nspname = #{name.schema ? "'#{name.schema}'" : 'ANY (current_schemas(false))'}
          SQL
        end

        def views # :nodoc:
          select_values(<<-SQL, 'SCHEMA')
            SELECT c.relname
            FROM pg_class c
            LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relkind IN ('v','m') -- (v)iew, (m)aterialized view
            AND n.nspname = ANY (current_schemas(false))
          SQL
        end

        def view_exists?(view_name) # :nodoc:
          name = Utils.extract_schema_qualified_name(view_name.to_s)
          return false unless name.identifier

          select_values(<<-SQL, 'SCHEMA').any?
            SELECT c.relname
            FROM pg_class c
            LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relkind IN ('v','m') -- (v)iew, (m)aterialized view
            AND c.relname = '#{name.identifier}'
            AND n.nspname = #{name.schema ? "'#{name.schema}'" : 'ANY (current_schemas(false))'}
          SQL
        end

        def drop_table(table_name, options = {}) # :nodoc:
          execute "DROP TABLE#{' IF EXISTS' if options[:if_exists]} #{quote_table_name(table_name)}#{' CASCADE' if options[:force] == :cascade}"
        end

        # Returns true if schema exists.
        def schema_exists?(name)
          select_value("SELECT COUNT(*) FROM pg_namespace WHERE nspname = '#{name}'", 'SCHEMA').to_i > 0
        end

        # Verifies existence of an index with a given name.
        def index_name_exists?(table_name, index_name, default)
          table = Utils.extract_schema_qualified_name(table_name.to_s)
          index = Utils.extract_schema_qualified_name(index_name.to_s)

          select_value(<<-SQL, 'SCHEMA').to_i > 0
            SELECT COUNT(*)
            FROM pg_class t
            INNER JOIN pg_index d ON t.oid = d.indrelid
            INNER JOIN pg_class i ON d.indexrelid = i.oid
            LEFT JOIN pg_namespace n ON n.oid = i.relnamespace
            WHERE i.relkind = 'i'
              AND i.relname = '#{index.identifier}'
              AND t.relname = '#{table.identifier}'
              AND n.nspname = #{index.schema ? "'#{index.schema}'" : 'ANY (current_schemas(false))'}
          SQL
        end

        # Returns an array of indexes for the given table.
        def indexes(table_name, name = nil)
          table = Utils.extract_schema_qualified_name(table_name.to_s)

          result = query(<<-SQL, 'SCHEMA')
            SELECT distinct i.relname, d.indisunique, d.indkey, pg_get_indexdef(d.indexrelid), t.oid,
                            pg_catalog.obj_description(i.oid, 'pg_class') AS comment,
            (SELECT COUNT(*) FROM pg_opclass o
               JOIN (SELECT unnest(string_to_array(d.indclass::text, ' '))::int oid) c
                 ON o.oid = c.oid WHERE o.opcdefault = 'f')
            FROM pg_class t
            INNER JOIN pg_index d ON t.oid = d.indrelid
            INNER JOIN pg_class i ON d.indexrelid = i.oid
            LEFT JOIN pg_namespace n ON n.oid = i.relnamespace
            WHERE i.relkind = 'i'
              AND d.indisprimary = 'f'
              AND t.relname = '#{table.identifier}'
              AND n.nspname = #{table.schema ? "'#{table.schema}'" : 'ANY (current_schemas(false))'}
            ORDER BY i.relname
          SQL

          result.map do |row|
            index_name = row[0]
            unique = row[1]
            indkey = row[2].split(" ").map(&:to_i)
            inddef = row[3]
            oid = row[4]
            comment = row[5]
            opclass = row[6]

            using, expressions, where = inddef.scan(/ USING (\w+?) \((.+?)\)(?: WHERE (.+))?\z/).flatten

            if indkey.include?(0) || opclass > 0
              columns = expressions
            else
              columns = Hash[query(<<-SQL.strip_heredoc, "SCHEMA")].values_at(*indkey).compact
                SELECT a.attnum, a.attname
                FROM pg_attribute a
                WHERE a.attrelid = #{oid}
                AND a.attnum IN (#{indkey.join(",")})
              SQL

              # add info on sort order for columns (only desc order is explicitly specified, asc is the default)
              orders = Hash[
                expressions.scan(/(\w+) DESC/).flatten.map { |order_column| [order_column, :desc] }
              ]
            end

            IndexDefinition.new(table_name, index_name, unique, columns, [], orders, where, nil, using.to_sym, comment.presence)
          end.compact
        end

        # Returns the list of all column definitions for a table.
        def columns(table_name) # :nodoc:
          table_name = table_name.to_s
          column_definitions(table_name).map do |column_name, type, default, notnull, oid, fmod, collation, comment|
            oid = oid.to_i
            fmod = fmod.to_i
            type_metadata = fetch_type_metadata(column_name, type, oid, fmod)
            default_value = extract_value_from_default(default)
            default_function = extract_default_function(default_value, default)
            new_column(column_name, default_value, type_metadata, !notnull, table_name, default_function, collation, comment: comment.presence)
          end
        end

        def new_column(*args) # :nodoc:
          PostgreSQLColumn.new(*args)
        end

        # Returns a comment stored in database for given table
        def table_comment(table_name) # :nodoc:
          name = Utils.extract_schema_qualified_name(table_name.to_s)
          if name.identifier
            select_value(<<-SQL.strip_heredoc, 'SCHEMA')
              SELECT pg_catalog.obj_description(c.oid, 'pg_class')
              FROM pg_catalog.pg_class c
                LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE c.relname = #{quote(name.identifier)}
                AND c.relkind IN ('r') -- (r)elation/table
                AND n.nspname = #{name.schema ? quote(name.schema) : 'ANY (current_schemas(false))'}
            SQL
          end
        end

        # Returns the current database name.
        def current_database
          select_value('select current_database()', 'SCHEMA')
        end

        # Returns the current schema name.
        def current_schema
          select_value('SELECT current_schema', 'SCHEMA')
        end

        # Returns the current database encoding format.
        def encoding
          select_value("SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname LIKE '#{current_database}'", 'SCHEMA')
        end

        # Returns the current database collation.
        def collation
          select_value("SELECT datcollate FROM pg_database WHERE datname LIKE '#{current_database}'", 'SCHEMA')
        end

        # Returns the current database ctype.
        def ctype
          select_value("SELECT datctype FROM pg_database WHERE datname LIKE '#{current_database}'", 'SCHEMA')
        end

        # Returns an array of schema names.
        def schema_names
          select_values(<<-SQL, 'SCHEMA')
            SELECT nspname
              FROM pg_namespace
             WHERE nspname !~ '^pg_.*'
               AND nspname NOT IN ('information_schema')
             ORDER by nspname;
          SQL
        end

        # Creates a schema for the given schema name.
        def create_schema schema_name
          execute "CREATE SCHEMA #{quote_schema_name(schema_name)}"
        end

        # Drops the schema for the given schema name.
        def drop_schema(schema_name, options = {})
          execute "DROP SCHEMA#{' IF EXISTS' if options[:if_exists]} #{quote_schema_name(schema_name)} CASCADE"
        end

        # Sets the schema search path to a string of comma-separated schema names.
        # Names beginning with $ have to be quoted (e.g. $user => '$user').
        # See: http://www.postgresql.org/docs/current/static/ddl-schemas.html
        #
        # This should be not be called manually but set in database.yml.
        def schema_search_path=(schema_csv)
          if schema_csv
            execute("SET search_path TO #{schema_csv}", 'SCHEMA')
            @schema_search_path = schema_csv
          end
        end

        # Returns the active schema search path.
        def schema_search_path
          @schema_search_path ||= select_value('SHOW search_path', 'SCHEMA')
        end

        # Returns the current client message level.
        def client_min_messages
          select_value('SHOW client_min_messages', 'SCHEMA')
        end

        # Set the client message level.
        def client_min_messages=(level)
          execute("SET client_min_messages TO '#{level}'", 'SCHEMA')
        end

        # Returns the sequence name for a table's primary key or some other specified key.
        def default_sequence_name(table_name, pk = nil) #:nodoc:
          result = serial_sequence(table_name, pk || 'id')
          return nil unless result
          Utils.extract_schema_qualified_name(result).to_s
        rescue ActiveRecord::StatementInvalid
          PostgreSQL::Name.new(nil, "#{table_name}_#{pk || 'id'}_seq").to_s
        end

        def serial_sequence(table, column)
          select_value("SELECT pg_get_serial_sequence('#{table}', '#{column}')", 'SCHEMA')
        end

        # Sets the sequence of a table's primary key to the specified value.
        def set_pk_sequence!(table, value) #:nodoc:
          pk, sequence = pk_and_sequence_for(table)

          if pk
            if sequence
              quoted_sequence = quote_table_name(sequence)

              select_value("SELECT setval('#{quoted_sequence}', #{value})", 'SCHEMA')
            else
              @logger.warn "#{table} has primary key #{pk} with no default sequence." if @logger
            end
          end
        end

        # Resets the sequence of a table's primary key to the maximum value.
        def reset_pk_sequence!(table, pk = nil, sequence = nil) #:nodoc:
          unless pk and sequence
            default_pk, default_sequence = pk_and_sequence_for(table)

            pk ||= default_pk
            sequence ||= default_sequence
          end

          if @logger && pk && !sequence
            @logger.warn "#{table} has primary key #{pk} with no default sequence."
          end

          if pk && sequence
            quoted_sequence = quote_table_name(sequence)

            select_value(<<-end_sql, 'SCHEMA')
              SELECT setval('#{quoted_sequence}', (SELECT COALESCE(MAX(#{quote_column_name pk})+(SELECT increment_by FROM #{quoted_sequence}), (SELECT min_value FROM #{quoted_sequence})) FROM #{quote_table_name(table)}), false)
            end_sql
          end
        end

        # Returns a table's primary key and belonging sequence.
        def pk_and_sequence_for(table) #:nodoc:
          # First try looking for a sequence with a dependency on the
          # given table's primary key.
          result = query(<<-end_sql, 'SCHEMA')[0]
            SELECT attr.attname, nsp.nspname, seq.relname
            FROM pg_class      seq,
                 pg_attribute  attr,
                 pg_depend     dep,
                 pg_constraint cons,
                 pg_namespace  nsp
            WHERE seq.oid           = dep.objid
              AND seq.relkind       = 'S'
              AND attr.attrelid     = dep.refobjid
              AND attr.attnum       = dep.refobjsubid
              AND attr.attrelid     = cons.conrelid
              AND attr.attnum       = cons.conkey[1]
              AND seq.relnamespace  = nsp.oid
              AND cons.contype      = 'p'
              AND dep.classid       = 'pg_class'::regclass
              AND dep.refobjid      = '#{quote_table_name(table)}'::regclass
          end_sql

          if result.nil? or result.empty?
            result = query(<<-end_sql, 'SCHEMA')[0]
              SELECT attr.attname, nsp.nspname,
                CASE
                  WHEN pg_get_expr(def.adbin, def.adrelid) !~* 'nextval' THEN NULL
                  WHEN split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2) ~ '.' THEN
                    substr(split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2),
                           strpos(split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2), '.')+1)
                  ELSE split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2)
                END
              FROM pg_class       t
              JOIN pg_attribute   attr ON (t.oid = attrelid)
              JOIN pg_attrdef     def  ON (adrelid = attrelid AND adnum = attnum)
              JOIN pg_constraint  cons ON (conrelid = adrelid AND adnum = conkey[1])
              JOIN pg_namespace   nsp  ON (t.relnamespace = nsp.oid)
              WHERE t.oid = '#{quote_table_name(table)}'::regclass
                AND cons.contype = 'p'
                AND pg_get_expr(def.adbin, def.adrelid) ~* 'nextval|uuid_generate'
            end_sql
          end

          pk = result.shift
          if result.last
            [pk, PostgreSQL::Name.new(*result)]
          else
            [pk, nil]
          end
        rescue
          nil
        end

        def primary_keys(table_name) # :nodoc:
          select_values(<<-SQL.strip_heredoc, 'SCHEMA')
            WITH pk_constraint AS (
              SELECT conrelid, unnest(conkey) AS connum FROM pg_constraint
              WHERE contype = 'p'
                AND conrelid = '#{quote_table_name(table_name)}'::regclass
            ), cons AS (
              SELECT conrelid, connum, row_number() OVER() AS rownum FROM pk_constraint
            )
            SELECT attr.attname FROM pg_attribute attr
            INNER JOIN cons ON attr.attrelid = cons.conrelid AND attr.attnum = cons.connum
            ORDER BY cons.rownum
          SQL
        end

        # Renames a table.
        # Also renames a table's primary key sequence if the sequence name exists and
        # matches the Active Record default.
        #
        # Example:
        #   rename_table('octopuses', 'octopi')
        def rename_table(table_name, new_name)
          clear_cache!
          execute "ALTER TABLE #{quote_table_name(table_name)} RENAME TO #{quote_table_name(new_name)}"
          pk, seq = pk_and_sequence_for(new_name)
          if seq && seq.identifier == "#{table_name}_#{pk}_seq"
            new_seq = "#{new_name}_#{pk}_seq"
            idx = "#{table_name}_pkey"
            new_idx = "#{new_name}_pkey"
            execute "ALTER TABLE #{seq.quoted} RENAME TO #{quote_table_name(new_seq)}"
            execute "ALTER INDEX #{quote_table_name(idx)} RENAME TO #{quote_table_name(new_idx)}"
          end

          rename_table_indexes(table_name, new_name)
        end

        def add_column(table_name, column_name, type, options = {}) #:nodoc:
          clear_cache!
          super
          change_column_comment(table_name, column_name, options[:comment]) if options.key?(:comment)
        end

        def change_column(table_name, column_name, type, options = {}) #:nodoc:
          clear_cache!
          quoted_table_name = quote_table_name(table_name)
          quoted_column_name = quote_column_name(column_name)
          sql_type = type_to_sql(type, options[:limit], options[:precision], options[:scale], options[:array])
          sql = "ALTER TABLE #{quoted_table_name} ALTER COLUMN #{quoted_column_name} TYPE #{sql_type}"
          if options[:collation]
            sql << " COLLATE \"#{options[:collation]}\""
          end
          if options[:using]
            sql << " USING #{options[:using]}"
          elsif options[:cast_as]
            cast_as_type = type_to_sql(options[:cast_as], options[:limit], options[:precision], options[:scale], options[:array])
            sql << " USING CAST(#{quoted_column_name} AS #{cast_as_type})"
          end
          execute sql

          change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)
          change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
          change_column_comment(table_name, column_name, options[:comment]) if options.key?(:comment)
        end

        # Changes the default value of a table column.
        def change_column_default(table_name, column_name, default_or_changes) # :nodoc:
          clear_cache!
          column = column_for(table_name, column_name)
          return unless column

          default = extract_new_default_value(default_or_changes)
          alter_column_query = "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} %s"
          if default.nil?
            # <tt>DEFAULT NULL</tt> results in the same behavior as <tt>DROP DEFAULT</tt>. However, PostgreSQL will
            # cast the default to the columns type, which leaves us with a default like "default NULL::character varying".
            execute alter_column_query % "DROP DEFAULT"
          else
            execute alter_column_query % "SET DEFAULT #{quote_default_expression(default, column)}"
          end
        end

        def change_column_null(table_name, column_name, null, default = nil) #:nodoc:
          clear_cache!
          unless null || default.nil?
            column = column_for(table_name, column_name)
            execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote_default_expression(default, column)} WHERE #{quote_column_name(column_name)} IS NULL") if column
          end
          execute("ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} #{null ? 'DROP' : 'SET'} NOT NULL")
        end

        # Adds comment for given table column or drops it if +comment+ is a +nil+
        def change_column_comment(table_name, column_name, comment) # :nodoc:
          clear_cache!
          execute "COMMENT ON COLUMN #{quote_table_name(table_name)}.#{quote_column_name(column_name)} IS #{quote(comment)}"
        end

        # Adds comment for given table or drops it if +comment+ is a +nil+
        def change_table_comment(table_name, comment) # :nodoc:
          clear_cache!
          execute "COMMENT ON TABLE #{quote_table_name(table_name)} IS #{quote(comment)}"
        end

        # Renames a column in a table.
        def rename_column(table_name, column_name, new_column_name) #:nodoc:
          clear_cache!
          execute "ALTER TABLE #{quote_table_name(table_name)} RENAME COLUMN #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
          rename_column_indexes(table_name, column_name, new_column_name)
        end

        def add_index(table_name, column_name, options = {}) #:nodoc:
          index_name, index_type, index_columns, index_options, index_algorithm, index_using, comment = add_index_options(table_name, column_name, options)
          execute("CREATE #{index_type} INDEX #{index_algorithm} #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} #{index_using} (#{index_columns})#{index_options}").tap do
            execute "COMMENT ON INDEX #{quote_column_name(index_name)} IS #{quote(comment)}" if comment
          end
        end

        def remove_index(table_name, options = {}) #:nodoc:
          table = Utils.extract_schema_qualified_name(table_name.to_s)

          if options.is_a?(Hash) && options.key?(:name)
            provided_index = Utils.extract_schema_qualified_name(options[:name].to_s)

            options[:name] = provided_index.identifier
            table = PostgreSQL::Name.new(provided_index.schema, table.identifier) unless table.schema.present?

            if provided_index.schema.present? && table.schema != provided_index.schema
              raise ArgumentError.new("Index schema '#{provided_index.schema}' does not match table schema '#{table.schema}'")
            end
          end

          index_to_remove = PostgreSQL::Name.new(table.schema, index_name_for_remove(table.to_s, options))
          algorithm =
            if options.is_a?(Hash) && options.key?(:algorithm)
              index_algorithms.fetch(options[:algorithm]) do
                raise ArgumentError.new("Algorithm must be one of the following: #{index_algorithms.keys.map(&:inspect).join(', ')}")
              end
            end
          execute "DROP INDEX #{algorithm} #{quote_table_name(index_to_remove)}"
        end

        # Renames an index of a table. Raises error if length of new
        # index name is greater than allowed limit.
        def rename_index(table_name, old_name, new_name)
          validate_index_length!(table_name, new_name)

          execute "ALTER INDEX #{quote_column_name(old_name)} RENAME TO #{quote_table_name(new_name)}"
        end

        def foreign_keys(table_name)
          fk_info = select_all <<-SQL.strip_heredoc
            SELECT t2.oid::regclass::text AS to_table, a1.attname AS column, a2.attname AS primary_key, c.conname AS name, c.confupdtype AS on_update, c.confdeltype AS on_delete
            FROM pg_constraint c
            JOIN pg_class t1 ON c.conrelid = t1.oid
            JOIN pg_class t2 ON c.confrelid = t2.oid
            JOIN pg_attribute a1 ON a1.attnum = c.conkey[1] AND a1.attrelid = t1.oid
            JOIN pg_attribute a2 ON a2.attnum = c.confkey[1] AND a2.attrelid = t2.oid
            JOIN pg_namespace t3 ON c.connamespace = t3.oid
            WHERE c.contype = 'f'
              AND t1.relname = #{quote(table_name)}
              AND t3.nspname = ANY (current_schemas(false))
            ORDER BY c.conname
          SQL

          fk_info.map do |row|
            options = {
              column: row['column'],
              name: row['name'],
              primary_key: row['primary_key']
            }

            options[:on_delete] = extract_foreign_key_action(row['on_delete'])
            options[:on_update] = extract_foreign_key_action(row['on_update'])

            ForeignKeyDefinition.new(table_name, row['to_table'], options)
          end
        end

        def extract_foreign_key_action(specifier) # :nodoc:
          case specifier
          when 'c'; :cascade
          when 'n'; :nullify
          when 'r'; :restrict
          end
        end

        def index_name_length
          63
        end

        # Maps logical Rails types to PostgreSQL-specific data types.
        def type_to_sql(type, limit = nil, precision = nil, scale = nil, array = nil)
          sql = case type.to_s
          when 'binary'
            # PostgreSQL doesn't support limits on binary (bytea) columns.
            # The hard limit is 1GB, because of a 32-bit size field, and TOAST.
            case limit
            when nil, 0..0x3fffffff; super(type)
            else raise(ActiveRecordError, "No binary type has byte size #{limit}.")
            end
          when 'text'
            # PostgreSQL doesn't support limits on text columns.
            # The hard limit is 1GB, according to section 8.3 in the manual.
            case limit
            when nil, 0..0x3fffffff; super(type)
            else raise(ActiveRecordError, "The limit on text can be at most 1GB - 1byte.")
            end
          when 'integer'
            case limit
            when 1, 2; 'smallint'
            when nil, 3, 4; 'integer'
            when 5..8; 'bigint'
            else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with precision 0 instead.")
            end
          else
            super(type, limit, precision, scale)
          end

          sql << '[]' if array && type != :primary_key
          sql
        end

        # PostgreSQL requires the ORDER BY columns in the select list for distinct queries, and
        # requires that the ORDER BY include the distinct column.
        def columns_for_distinct(columns, orders) #:nodoc:
          order_columns = orders.reject(&:blank?).map{ |s|
              # Convert Arel node to string
              s = s.to_sql unless s.is_a?(String)
              # Remove any ASC/DESC modifiers
              s.gsub(/\s+(?:ASC|DESC)\b/i, '')
               .gsub(/\s+NULLS\s+(?:FIRST|LAST)\b/i, '')
            }.reject(&:blank?).map.with_index { |column, i| "#{column} AS alias_#{i}" }

          [super, *order_columns].join(', ')
        end

        def fetch_type_metadata(column_name, sql_type, oid, fmod)
          cast_type = get_oid_type(oid, fmod, column_name, sql_type)
          simple_type = SqlTypeMetadata.new(
            sql_type: sql_type,
            type: cast_type.type,
            limit: cast_type.limit,
            precision: cast_type.precision,
            scale: cast_type.scale,
          )
          PostgreSQLTypeMetadata.new(simple_type, oid: oid, fmod: fmod)
        end
      end
    end
  end
end
