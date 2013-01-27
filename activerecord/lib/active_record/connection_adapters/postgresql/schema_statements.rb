module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      module SchemaStatements
        # Drops the database specified on the +name+ attribute
        # and creates it again using the provided +options+.
        def recreate_database(name, options = {}) #:nodoc:
          drop_database(name)
          create_database(name, options)
        end

        # Create a new PostgreSQL database. Options include <tt>:owner</tt>, <tt>:template</tt>,
        # <tt>:encoding</tt>, <tt>:collation</tt>, <tt>:ctype</tt>,
        # <tt>:tablespace</tt>, and <tt>:connection_limit</tt> (note that MySQL uses
        # <tt>:charset</tt> while PostgreSQL uses <tt>:encoding</tt>).
        #
        # Example:
        #   create_database config[:database], config
        #   create_database 'foo_development', encoding: 'unicode'
        def create_database(name, options = {})
          options = { encoding: 'utf8' }.merge!(options.symbolize_keys)

          option_string = options.sum do |key, value|
            case key
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

        # Returns the list of all tables in the schema search path or a specified schema.
        def tables(name = nil)
          query(<<-SQL, 'SCHEMA').map { |row| row[0] }
            SELECT tablename
            FROM pg_tables
            WHERE schemaname = ANY (current_schemas(false))
          SQL
        end

        # Returns true if table exists.
        # If the schema is not specified as part of +name+ then it will only find tables within
        # the current schema search path (regardless of permissions to access tables in other schemas)
        def table_exists?(name)
          schema, table = Utils.extract_schema_and_table(name.to_s)
          return false unless table

          binds = [[nil, table]]
          binds << [nil, schema] if schema

          exec_query(<<-SQL, 'SCHEMA').rows.first[0].to_i > 0
              SELECT COUNT(*)
              FROM pg_class c
              LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE c.relkind in ('v','r')
              AND c.relname = '#{table.gsub(/(^"|"$)/,'')}'
              AND n.nspname = #{schema ? "'#{schema}'" : 'ANY (current_schemas(false))'}
          SQL
        end

        # Returns true if schema exists.
        def schema_exists?(name)
          exec_query(<<-SQL, 'SCHEMA').rows.first[0].to_i > 0
            SELECT COUNT(*)
            FROM pg_namespace
            WHERE nspname = '#{name}'
          SQL
        end

        # Returns an array of indexes for the given table.
        def indexes(table_name, name = nil)
           result = query(<<-SQL, 'SCHEMA')
             SELECT distinct i.relname, d.indisunique, d.indkey, pg_get_indexdef(d.indexrelid), t.oid
             FROM pg_class t
             INNER JOIN pg_index d ON t.oid = d.indrelid
             INNER JOIN pg_class i ON d.indexrelid = i.oid
             WHERE i.relkind = 'i'
               AND d.indisprimary = 'f'
               AND t.relname = '#{table_name}'
               AND i.relnamespace IN (SELECT oid FROM pg_namespace WHERE nspname = ANY (current_schemas(false)) )
            ORDER BY i.relname
          SQL

          result.map do |row|
            index_name = row[0]
            unique = row[1] == 't'
            indkey = row[2].split(" ")
            inddef = row[3]
            oid = row[4]

            columns = Hash[query(<<-SQL, "SCHEMA")]
            SELECT a.attnum, a.attname
            FROM pg_attribute a
            WHERE a.attrelid = #{oid}
            AND a.attnum IN (#{indkey.join(",")})
            SQL

            column_names = columns.values_at(*indkey).compact

            # add info on sort order for columns (only desc order is explicitly specified, asc is the default)
            desc_order_columns = inddef.scan(/(\w+) DESC/).flatten
            orders = desc_order_columns.any? ? Hash[desc_order_columns.map {|order_column| [order_column, :desc]}] : {}
            where = inddef.scan(/WHERE (.+)$/).flatten[0]

            column_names.empty? ? nil : IndexDefinition.new(table_name, index_name, unique, column_names, [], orders, where)
          end.compact
        end

        # Returns the list of all column definitions for a table.
        def columns(table_name)
          # Limit, precision, and scale are all handled by the superclass.
          column_definitions(table_name).map do |column_name, type, default, notnull, oid, fmod|
            oid = OID::TYPE_MAP.fetch(oid.to_i, fmod.to_i) {
              OID::Identity.new
            }
            PostgreSQLColumn.new(column_name, default, oid, type, notnull == 'f')
          end
        end

        # Returns the current database name.
        def current_database
          query('select current_database()', 'SCHEMA')[0][0]
        end

        # Returns the current schema name.
        def current_schema
          query('SELECT current_schema', 'SCHEMA')[0][0]
        end

        # Returns the current database encoding format.
        def encoding
          query(<<-end_sql, 'SCHEMA')[0][0]
            SELECT pg_encoding_to_char(pg_database.encoding) FROM pg_database
            WHERE pg_database.datname LIKE '#{current_database}'
          end_sql
        end

        # Returns the current database collation.
        def collation
          query(<<-end_sql, 'SCHEMA')[0][0]
            SELECT pg_database.datcollate FROM pg_database WHERE pg_database.datname LIKE '#{current_database}'
          end_sql
        end

        # Returns the current database ctype.
        def ctype
          query(<<-end_sql, 'SCHEMA')[0][0]
            SELECT pg_database.datctype FROM pg_database WHERE pg_database.datname LIKE '#{current_database}'
          end_sql
        end

        # Returns an array of schema names.
        def schema_names
          query(<<-SQL, 'SCHEMA').flatten
            SELECT nspname
              FROM pg_namespace
             WHERE nspname !~ '^pg_.*'
               AND nspname NOT IN ('information_schema')
             ORDER by nspname;
          SQL
        end

        # Creates a schema for the given schema name.
        def create_schema schema_name
          execute "CREATE SCHEMA #{schema_name}"
        end

        # Drops the schema for the given schema name.
        def drop_schema schema_name
          execute "DROP SCHEMA #{schema_name} CASCADE"
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
          @schema_search_path ||= query('SHOW search_path', 'SCHEMA')[0][0]
        end

        # Returns the current client message level.
        def client_min_messages
          query('SHOW client_min_messages', 'SCHEMA')[0][0]
        end

        # Set the client message level.
        def client_min_messages=(level)
          execute("SET client_min_messages TO '#{level}'", 'SCHEMA')
        end

        # Returns the sequence name for a table's primary key or some other specified key.
        def default_sequence_name(table_name, pk = nil) #:nodoc:
          result = serial_sequence(table_name, pk || 'id')
          return nil unless result
          result.split('.').last
        rescue ActiveRecord::StatementInvalid
          "#{table_name}_#{pk || 'id'}_seq"
        end

        def serial_sequence(table, column)
          result = exec_query(<<-eosql, 'SCHEMA')
            SELECT pg_get_serial_sequence('#{table}', '#{column}')
          eosql
          result.rows.first.first
        end

        # Resets the sequence of a table's primary key to the maximum value.
        def reset_pk_sequence!(table, pk = nil, sequence = nil) #:nodoc:
          unless pk and sequence
            default_pk, default_sequence = pk_and_sequence_for(table)

            pk ||= default_pk
            sequence ||= default_sequence
          end

          if @logger && pk && !sequence
            @logger.warn "#{table} has primary key #{pk} with no default sequence"
          end

          if pk && sequence
            quoted_sequence = quote_table_name(sequence)

            select_value <<-end_sql, 'SCHEMA'
              SELECT setval('#{quoted_sequence}', (SELECT COALESCE(MAX(#{quote_column_name pk})+(SELECT increment_by FROM #{quoted_sequence}), (SELECT min_value FROM #{quoted_sequence})) FROM #{quote_table_name(table)}), false)
            end_sql
          end
        end

        # Returns a table's primary key and belonging sequence.
        def pk_and_sequence_for(table) #:nodoc:
          # First try looking for a sequence with a dependency on the
          # given table's primary key.
          result = query(<<-end_sql, 'SCHEMA')[0]
            SELECT attr.attname, seq.relname
            FROM pg_class      seq,
                 pg_attribute  attr,
                 pg_depend     dep,
                 pg_constraint cons
            WHERE seq.oid           = dep.objid
              AND seq.relkind       = 'S'
              AND attr.attrelid     = dep.refobjid
              AND attr.attnum       = dep.refobjsubid
              AND attr.attrelid     = cons.conrelid
              AND attr.attnum       = cons.conkey[1]
              AND cons.contype      = 'p'
              AND dep.refobjid      = '#{quote_table_name(table)}'::regclass
          end_sql

          if result.nil? or result.empty?
            result = query(<<-end_sql, 'SCHEMA')[0]
              SELECT attr.attname,
                CASE
                  WHEN split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2) ~ '.' THEN
                    substr(split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2),
                           strpos(split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2), '.')+1)
                  ELSE split_part(pg_get_expr(def.adbin, def.adrelid), '''', 2)
                END
              FROM pg_class       t
              JOIN pg_attribute   attr ON (t.oid = attrelid)
              JOIN pg_attrdef     def  ON (adrelid = attrelid AND adnum = attnum)
              JOIN pg_constraint  cons ON (conrelid = adrelid AND adnum = conkey[1])
              WHERE t.oid = '#{quote_table_name(table)}'::regclass
                AND cons.contype = 'p'
                AND pg_get_expr(def.adbin, def.adrelid) ~* 'nextval'
            end_sql
          end

          [result.first, result.last]
        rescue
          nil
        end

        # Returns just a table's primary key
        def primary_key(table)
          row = exec_query(<<-end_sql, 'SCHEMA').rows.first
            SELECT attr.attname
            FROM pg_attribute attr
            INNER JOIN pg_constraint cons ON attr.attrelid = cons.conrelid AND attr.attnum = cons.conkey[1]
            WHERE cons.contype = 'p'
              AND cons.conrelid = '#{quote_table_name(table)}'::regclass
          end_sql

          row && row.first
        end

        # Renames a table.
        # Also renames a table's primary key sequence if the sequence name matches the
        # Active Record default.
        #
        # Example:
        #   rename_table('octopuses', 'octopi')
        def rename_table(name, new_name)
          clear_cache!
          execute "ALTER TABLE #{quote_table_name(name)} RENAME TO #{quote_table_name(new_name)}"
          pk, seq = pk_and_sequence_for(new_name)
          if seq == "#{name}_#{pk}_seq"
            new_seq = "#{new_name}_#{pk}_seq"
            execute "ALTER TABLE #{quote_table_name(seq)} RENAME TO #{quote_table_name(new_seq)}"
          end
        end

        # Adds a new column to the named table.
        # See TableDefinition#column for details of the options you can use.
        def add_column(table_name, column_name, type, options = {})
          clear_cache!
          add_column_sql = "ALTER TABLE #{quote_table_name(table_name)} ADD COLUMN #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
          add_column_options!(add_column_sql, options)

          execute add_column_sql
        end

        # Changes the column of a table.
        def change_column(table_name, column_name, type, options = {})
          clear_cache!
          quoted_table_name = quote_table_name(table_name)

          execute "ALTER TABLE #{quoted_table_name} ALTER COLUMN #{quote_column_name(column_name)} TYPE #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"

          change_column_default(table_name, column_name, options[:default]) if options_include_default?(options)
          change_column_null(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
        end

        # Changes the default value of a table column.
        def change_column_default(table_name, column_name, default)
          clear_cache!
          execute "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} SET DEFAULT #{quote(default)}"
        end

        def change_column_null(table_name, column_name, null, default = nil)
          clear_cache!
          unless null || default.nil?
            execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
          end
          execute("ALTER TABLE #{quote_table_name(table_name)} ALTER #{quote_column_name(column_name)} #{null ? 'DROP' : 'SET'} NOT NULL")
        end

        # Renames a column in a table.
        def rename_column(table_name, column_name, new_column_name)
          clear_cache!
          execute "ALTER TABLE #{quote_table_name(table_name)} RENAME COLUMN #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
        end

        def remove_index!(table_name, index_name) #:nodoc:
          execute "DROP INDEX #{quote_table_name(index_name)}"
        end

        def rename_index(table_name, old_name, new_name)
          execute "ALTER INDEX #{quote_column_name(old_name)} RENAME TO #{quote_table_name(new_name)}"
        end

        def index_name_length
          63
        end

        # Maps logical Rails types to PostgreSQL-specific data types.
        def type_to_sql(type, limit = nil, precision = nil, scale = nil)
          case type.to_s
          when 'binary'
            # PostgreSQL doesn't support limits on binary (bytea) columns.
            # The hard limit is 1Gb, because of a 32-bit size field, and TOAST.
            case limit
            when nil, 0..0x3fffffff; super(type)
            else raise(ActiveRecordError, "No binary type has byte size #{limit}.")
            end
          when 'text'
            # PostgreSQL doesn't support limits on text columns.
            # The hard limit is 1Gb, according to section 8.3 in the manual.
            case limit
            when nil, 0..0x3fffffff; super(type)
            else raise(ActiveRecordError, "The limit on text can be at most 1GB - 1byte.")
            end
          when 'integer'
            return 'integer' unless limit

            case limit
              when 1, 2; 'smallint'
              when 3, 4; 'integer'
              when 5..8; 'bigint'
              else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with precision 0 instead.")
            end
          when 'datetime'
            return super unless precision

            case precision
              when 0..6; "timestamp(#{precision})"
              else raise(ActiveRecordError, "No timestamp type has precision of #{precision}. The allowed range of precision is from 0 to 6")
            end
          else
            super
          end
        end

        # Returns a SELECT DISTINCT clause for a given set of columns and a given ORDER BY clause.
        #
        # PostgreSQL requires the ORDER BY columns in the select list for distinct queries, and
        # requires that the ORDER BY include the distinct column.
        #
        #   distinct("posts.id", ["posts.created_at desc"])
        #   # => "DISTINCT posts.id, posts.created_at AS alias_0"
        def distinct(columns, orders) #:nodoc:
          order_columns = orders.map{ |s|
              # Convert Arel node to string
              s = s.to_sql unless s.is_a?(String)
              # Remove any ASC/DESC modifiers
              s.gsub(/\s+(ASC|DESC)\s*(NULLS\s+(FIRST|LAST)\s*)?/i, '')
            }.reject(&:blank?).map.with_index { |column, i| "#{column} AS alias_#{i}" }

          [super].concat(order_columns).join(', ')
        end
      end
    end
  end
end
