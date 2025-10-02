# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module SchemaStatements
        # Drops the database specified on the +name+ attribute
        # and creates it again using the provided +options+.
        def recreate_database(name, options = {}) # :nodoc:
          drop_database(name)
          create_database(name, options)
        end

        # Create a new PostgreSQL database. Options include <tt>:owner</tt>, <tt>:template</tt>,
        # <tt>:encoding</tt> (defaults to utf8), <tt>:locale_provider</tt>, <tt>:locale</tt>,
        # <tt>:collation</tt>, <tt>:ctype</tt>, <tt>:tablespace</tt>, and
        # <tt>:connection_limit</tt> (note that MySQL uses <tt>:charset</tt> while PostgreSQL
        # uses <tt>:encoding</tt>).
        #
        # Example:
        #   create_database config[:database], config
        #   create_database 'foo_development', encoding: 'unicode'
        def create_database(name, options = {})
          options = { encoding: "utf8" }.merge!(options.symbolize_keys)

          option_string = options.each_with_object(+"") do |(key, value), memo|
            memo << case key
                    when :owner
                      " OWNER = \"#{value}\""
                    when :template
                      " TEMPLATE = \"#{value}\""
                    when :encoding
                      " ENCODING = '#{value}'"
                    when :locale_provider
                      " LOCALE_PROVIDER = '#{value}'"
                    when :locale
                      " LOCALE = '#{value}'"
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
        def drop_database(name) # :nodoc:
          execute "DROP DATABASE IF EXISTS #{quote_table_name(name)}"
        end

        def drop_table(*table_names, **options) # :nodoc:
          table_names.each { |table_name| schema_cache.clear_data_source_cache!(table_name.to_s) }
          execute "DROP TABLE#{' IF EXISTS' if options[:if_exists]} #{table_names.map { |table_name| quote_table_name(table_name) }.join(', ')}#{' CASCADE' if options[:force] == :cascade}"
        end

        # Returns true if schema exists.
        def schema_exists?(name)
          query_value("SELECT COUNT(*) FROM pg_namespace WHERE nspname = #{quote(name)}", "SCHEMA").to_i > 0
        end

        # Verifies existence of an index with a given name.
        def index_name_exists?(table_name, index_name)
          table = quoted_scope(table_name)
          index = quoted_scope(index_name)

          query_value(<<~SQL, "SCHEMA").to_i > 0
            SELECT COUNT(*)
            FROM pg_class t
            INNER JOIN pg_index d ON t.oid = d.indrelid
            INNER JOIN pg_class i ON d.indexrelid = i.oid
            LEFT JOIN pg_namespace n ON n.oid = t.relnamespace
            WHERE i.relkind IN ('i', 'I')
              AND i.relname = #{index[:name]}
              AND t.relname = #{table[:name]}
              AND n.nspname = #{table[:schema]}
          SQL
        end

        # Returns an array of indexes for the given table.
        def indexes(table_name) # :nodoc:
          scope = quoted_scope(table_name)

          result = query(<<~SQL, "SCHEMA")
            SELECT distinct i.relname, d.indisunique, d.indkey, pg_get_indexdef(d.indexrelid),
                            pg_catalog.obj_description(i.oid, 'pg_class') AS comment, d.indisvalid,
                            ARRAY(
                              SELECT pg_get_indexdef(d.indexrelid, k + 1, true)
                              FROM generate_subscripts(d.indkey, 1) AS k
                              ORDER BY k
                            ) AS columns
            FROM pg_class t
            INNER JOIN pg_index d ON t.oid = d.indrelid
            INNER JOIN pg_class i ON d.indexrelid = i.oid
            LEFT JOIN pg_namespace n ON n.oid = t.relnamespace
            WHERE i.relkind IN ('i', 'I')
              AND d.indisprimary = 'f'
              AND t.relname = #{scope[:name]}
              AND n.nspname = #{scope[:schema]}
            ORDER BY i.relname
          SQL

          result.map do |row|
            index_name = row[0]
            unique = row[1]
            indkey = row[2].split(" ").map(&:to_i)
            inddef = row[3]
            comment = row[4]
            valid = row[5]
            columns = decode_string_array(row[6]).map { |c| Utils.unquote_identifier(c.strip.gsub('""', '"')) }

            using, expressions, include, nulls_not_distinct, where = inddef.scan(/ USING (\w+?) \((.+?)\)(?: INCLUDE \((.+?)\))?( NULLS NOT DISTINCT)?(?: WHERE (.+))?\z/m).flatten

            orders = {}
            opclasses = {}
            include_columns = include ? include.split(",").map { |c| Utils.unquote_identifier(c.strip.gsub('""', '"')) } : []

            if indkey.include?(0)
              columns = expressions
            else
              # prevent INCLUDE columns from being matched
              columns.reject! { |c| include_columns.include?(c) }

              # add info on sort order (only desc order is explicitly specified, asc is the default)
              # and non-default opclasses
              expressions.scan(/(?<column>\w+)"?\s?(?<opclass>\w+_ops(_\w+)?)?\s?(?<desc>DESC)?\s?(?<nulls>NULLS (?:FIRST|LAST))?/).each do |column, opclass, desc, nulls|
                opclasses[column] = opclass.to_sym if opclass
                if nulls
                  orders[column] = [desc, nulls].compact.join(" ")
                else
                  orders[column] = :desc if desc
                end
              end
            end

            IndexDefinition.new(
              table_name,
              index_name,
              unique,
              columns,
              orders: orders,
              opclasses: opclasses,
              where: where,
              using: using.to_sym,
              include: include_columns.presence,
              nulls_not_distinct: nulls_not_distinct.present?,
              comment: comment.presence,
              valid: valid
            )
          end
        end

        def table_options(table_name) # :nodoc:
          options = {}

          comment = table_comment(table_name)

          options[:comment] = comment if comment

          inherited_table_names = inherited_table_names(table_name).presence

          options[:options] = "INHERITS (#{inherited_table_names.join(", ")})" if inherited_table_names

          if !options[:options] && supports_native_partitioning?
            partition_definition = table_partition_definition(table_name)

            options[:options] = "PARTITION BY #{partition_definition}" if partition_definition
          end

          options
        end

        # Returns a comment stored in database for given table
        def table_comment(table_name) # :nodoc:
          scope = quoted_scope(table_name, type: "BASE TABLE")
          if scope[:name]
            query_value(<<~SQL, "SCHEMA")
              SELECT pg_catalog.obj_description(c.oid, 'pg_class')
              FROM pg_catalog.pg_class c
                LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE c.relname = #{scope[:name]}
                AND c.relkind IN (#{scope[:type]})
                AND n.nspname = #{scope[:schema]}
            SQL
          end
        end

        # Returns the partition definition of a given table
        def table_partition_definition(table_name) # :nodoc:
          scope = quoted_scope(table_name, type: "BASE TABLE")

          query_value(<<~SQL, "SCHEMA")
            SELECT pg_catalog.pg_get_partkeydef(c.oid)
            FROM pg_catalog.pg_class c
              LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE c.relname = #{scope[:name]}
              AND c.relkind IN (#{scope[:type]})
              AND n.nspname = #{scope[:schema]}
          SQL
        end

        # Returns the inherited table name of a given table
        def inherited_table_names(table_name) # :nodoc:
          scope = quoted_scope(table_name, type: "BASE TABLE")

          query_values(<<~SQL, "SCHEMA")
            SELECT parent.relname
            FROM pg_catalog.pg_inherits i
              JOIN pg_catalog.pg_class child ON i.inhrelid = child.oid
              JOIN pg_catalog.pg_class parent ON i.inhparent = parent.oid
              LEFT JOIN pg_namespace n ON n.oid = child.relnamespace
            WHERE child.relname = #{scope[:name]}
              AND child.relkind IN (#{scope[:type]})
              AND n.nspname = #{scope[:schema]}
          SQL
        end

        # Returns the current database name.
        def current_database
          query_value("SELECT current_database()", "SCHEMA")
        end

        # Returns the current schema name.
        def current_schema
          query_value("SELECT current_schema", "SCHEMA")
        end

        # Returns an array of the names of all schemas presently in the effective search path,
        # in their priority order.
        def current_schemas # :nodoc:
          schemas = query_value("SELECT current_schemas(false)", "SCHEMA")
          decoder = PG::TextDecoder::Array.new
          decoder.decode(schemas)
        end

        # Returns the current database encoding format.
        def encoding
          query_value("SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = current_database()", "SCHEMA")
        end

        # Returns the current database collation.
        def collation
          query_value("SELECT datcollate FROM pg_database WHERE datname = current_database()", "SCHEMA")
        end

        # Returns the current database ctype.
        def ctype
          query_value("SELECT datctype FROM pg_database WHERE datname = current_database()", "SCHEMA")
        end

        # Returns an array of schema names.
        def schema_names
          query_values(<<~SQL, "SCHEMA")
            SELECT nspname
              FROM pg_namespace
             WHERE nspname !~ '^pg_.*'
               AND nspname NOT IN ('information_schema')
             ORDER by nspname;
          SQL
        end

        # Creates a schema for the given schema name.
        def create_schema(schema_name, force: nil, if_not_exists: nil)
          if force && if_not_exists
            raise ArgumentError, "Options `:force` and `:if_not_exists` cannot be used simultaneously."
          end

          if force
            drop_schema(schema_name, if_exists: true)
          end

          execute("CREATE SCHEMA#{' IF NOT EXISTS' if if_not_exists} #{quote_schema_name(schema_name)}")
        end

        # Drops the schema for the given schema name.
        def drop_schema(schema_name, **options)
          execute "DROP SCHEMA#{' IF EXISTS' if options[:if_exists]} #{quote_schema_name(schema_name)} CASCADE"
        end

        # Renames the schema for the given schema name.
        def rename_schema(schema_name, new_name)
          execute "ALTER SCHEMA #{quote_schema_name(schema_name)} RENAME TO #{quote_schema_name(new_name)}"
        end

        # Sets the schema search path to a string of comma-separated schema names.
        # Names beginning with $ have to be quoted (e.g. $user => '$user').
        # See: https://www.postgresql.org/docs/current/static/ddl-schemas.html
        #
        # This should be not be called manually but set in database.yml.
        def schema_search_path=(schema_csv)
          return if schema_csv == @schema_search_path
          if schema_csv
            internal_execute("SET search_path TO #{schema_csv}")
            @schema_search_path = schema_csv
          end
        end

        # Returns the active schema search path.
        def schema_search_path
          @schema_search_path ||= query_value("SHOW search_path", "SCHEMA")
        end

        # Returns the current client message level.
        def client_min_messages
          query_value("SHOW client_min_messages", "SCHEMA")
        end

        # Set the client message level.
        def client_min_messages=(level)
          internal_execute("SET client_min_messages TO '#{level}'", "SCHEMA")
        end

        # Returns the sequence name for a table's primary key or some other specified key.
        def default_sequence_name(table_name, pk = "id") # :nodoc:
          return nil if pk.is_a?(Array)

          result = serial_sequence(table_name, pk)
          return nil unless result
          Utils.extract_schema_qualified_name(result).to_s
        rescue ActiveRecord::StatementInvalid
          PostgreSQL::Name.new(nil, "#{table_name}_#{pk}_seq").to_s
        end

        def serial_sequence(table, column)
          query_value("SELECT pg_get_serial_sequence(#{quote(table)}, #{quote(column)})", "SCHEMA")
        end

        # Sets the sequence of a table's primary key to the specified value.
        def set_pk_sequence!(table, value) # :nodoc:
          pk, sequence = pk_and_sequence_for(table)

          if pk
            if sequence
              quoted_sequence = quote_table_name(sequence)

              internal_execute("SELECT setval(#{quote(quoted_sequence)}, #{value})", "SCHEMA")
            else
              @logger.warn "#{table} has primary key #{pk} with no default sequence." if @logger
            end
          end
        end

        # Resets the sequence of a table's primary key to the maximum value.
        def reset_pk_sequence!(table, pk = nil, sequence = nil) # :nodoc:
          unless pk && sequence
            default_pk, default_sequence = pk_and_sequence_for(table)

            pk ||= default_pk
            sequence ||= default_sequence
          end

          if @logger && pk && !sequence
            @logger.warn "#{table} has primary key #{pk} with no default sequence."
          end

          if pk && sequence
            quoted_sequence = quote_table_name(sequence)
            max_pk = query_value("SELECT MAX(#{quote_column_name pk}) FROM #{quote_table_name(table)}", "SCHEMA")
            if max_pk.nil?
              if database_version >= 10_00_00
                minvalue = query_value("SELECT seqmin FROM pg_sequence WHERE seqrelid = #{quote(quoted_sequence)}::regclass", "SCHEMA")
              else
                minvalue = query_value("SELECT min_value FROM #{quoted_sequence}", "SCHEMA")
              end
            end

            internal_execute("SELECT setval(#{quote(quoted_sequence)}, #{max_pk || minvalue}, #{max_pk ? true : false})", "SCHEMA")
          end
        end

        # Returns a table's primary key and belonging sequence.
        def pk_and_sequence_for(table) # :nodoc:
          # First try looking for a sequence with a dependency on the
          # given table's primary key.
          result = query(<<~SQL, "SCHEMA")[0]
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
              AND dep.refobjid      = #{quote(quote_table_name(table))}::regclass
          SQL

          if result.nil? || result.empty?
            result = query(<<~SQL, "SCHEMA")[0]
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
              WHERE t.oid = #{quote(quote_table_name(table))}::regclass
                AND cons.contype = 'p'
                AND pg_get_expr(def.adbin, def.adrelid) ~* 'nextval|uuid_generate|gen_random_uuid'
            SQL
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
          query_values(<<~SQL, "SCHEMA")
            SELECT a.attname
            FROM pg_index i
            JOIN pg_attribute a
              ON a.attrelid = i.indrelid
              AND a.attnum = ANY(i.indkey)
            WHERE i.indrelid = #{quote(quote_table_name(table_name))}::regclass
              AND i.indisprimary
            ORDER BY array_position(i.indkey, a.attnum)
          SQL
        end

        # Renames a table.
        # Also renames a table's primary key sequence if the sequence name exists and
        # matches the Active Record default.
        #
        # Example:
        #   rename_table('octopuses', 'octopi')
        def rename_table(table_name, new_name, **options)
          validate_table_length!(new_name) unless options[:_uses_legacy_table_name]
          clear_cache!
          schema_cache.clear_data_source_cache!(table_name.to_s)
          schema_cache.clear_data_source_cache!(new_name.to_s)
          execute "ALTER TABLE #{quote_table_name(table_name)} RENAME TO #{quote_table_name(new_name)}"
          pk, seq = pk_and_sequence_for(new_name)
          if pk
            # PostgreSQL automatically creates an index for PRIMARY KEY with name consisting of
            # truncated table name and "_pkey" suffix fitting into max_identifier_length number of characters.
            max_pkey_prefix = max_identifier_length - "_pkey".size
            idx = "#{table_name[0, max_pkey_prefix]}_pkey"
            new_idx = "#{new_name[0, max_pkey_prefix]}_pkey"
            execute "ALTER INDEX #{quote_table_name(idx)} RENAME TO #{quote_table_name(new_idx)}"

            # PostgreSQL automatically creates a sequence for PRIMARY KEY with name consisting of
            # truncated table name and "#{primary_key}_seq" suffix fitting into max_identifier_length number of characters.
            max_seq_prefix = max_identifier_length - "_#{pk}_seq".size
            if seq && seq.identifier == "#{table_name[0, max_seq_prefix]}_#{pk}_seq"
              new_seq = "#{new_name[0, max_seq_prefix]}_#{pk}_seq"
              execute "ALTER TABLE #{seq.quoted} RENAME TO #{quote_table_name(new_seq)}"
            end
          end
          rename_table_indexes(table_name, new_name, **options)
        end

        def add_column(table_name, column_name, type, **options) # :nodoc:
          clear_cache!
          super
          change_column_comment(table_name, column_name, options[:comment]) if options.key?(:comment)
        end

        def change_column(table_name, column_name, type, **options) # :nodoc:
          clear_cache!
          sqls, procs = Array(change_column_for_alter(table_name, column_name, type, **options)).partition { |v| v.is_a?(String) }
          execute "ALTER TABLE #{quote_table_name(table_name)} #{sqls.join(", ")}"
          procs.each(&:call)
        end

        # Builds a ChangeColumnDefinition object.
        #
        # This definition object contains information about the column change that would occur
        # if the same arguments were passed to #change_column. See #change_column for information about
        # passing a +table_name+, +column_name+, +type+ and other options that can be passed.
        def build_change_column_definition(table_name, column_name, type, **options) # :nodoc:
          td = create_table_definition(table_name)
          cd = td.new_column_definition(column_name, type, **options)
          ChangeColumnDefinition.new(cd, column_name)
        end

        # Changes the default value of a table column.
        def change_column_default(table_name, column_name, default_or_changes) # :nodoc:
          execute "ALTER TABLE #{quote_table_name(table_name)} #{change_column_default_for_alter(table_name, column_name, default_or_changes)}"
        end

        def build_change_column_default_definition(table_name, column_name, default_or_changes) # :nodoc:
          column = column_for(table_name, column_name)
          return unless column

          default = extract_new_default_value(default_or_changes)
          ChangeColumnDefaultDefinition.new(column, default)
        end

        def change_column_null(table_name, column_name, null, default = nil) # :nodoc:
          validate_change_column_null_argument!(null)

          clear_cache!
          unless null || default.nil?
            column = column_for(table_name, column_name)
            execute "UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote_default_expression(default, column)} WHERE #{quote_column_name(column_name)} IS NULL" if column
          end
          execute "ALTER TABLE #{quote_table_name(table_name)} ALTER COLUMN #{quote_column_name(column_name)} #{null ? 'DROP' : 'SET'} NOT NULL"
        end

        # Adds comment for given table column or drops it if +comment+ is a +nil+
        def change_column_comment(table_name, column_name, comment_or_changes) # :nodoc:
          clear_cache!
          comment = extract_new_comment_value(comment_or_changes)
          execute "COMMENT ON COLUMN #{quote_table_name(table_name)}.#{quote_column_name(column_name)} IS #{quote(comment)}"
        end

        # Adds comment for given table or drops it if +comment+ is a +nil+
        def change_table_comment(table_name, comment_or_changes) # :nodoc:
          clear_cache!
          comment = extract_new_comment_value(comment_or_changes)
          execute "COMMENT ON TABLE #{quote_table_name(table_name)} IS #{quote(comment)}"
        end

        # Renames a column in a table.
        def rename_column(table_name, column_name, new_column_name) # :nodoc:
          clear_cache!
          execute("ALTER TABLE #{quote_table_name(table_name)} #{rename_column_sql(table_name, column_name, new_column_name)}")
          rename_column_indexes(table_name, column_name, new_column_name)
        end

        def add_index(table_name, column_name, **options) # :nodoc:
          create_index = build_create_index_definition(table_name, column_name, **options)
          result = execute schema_creation.accept(create_index)

          index = create_index.index
          execute "COMMENT ON INDEX #{quote_column_name(index.name)} IS #{quote(index.comment)}" if index.comment
          result
        end

        def build_create_index_definition(table_name, column_name, **options) # :nodoc:
          index, algorithm, if_not_exists = add_index_options(table_name, column_name, **options)
          CreateIndexDefinition.new(index, algorithm, if_not_exists)
        end

        def remove_index(table_name, column_name = nil, **options) # :nodoc:
          table = Utils.extract_schema_qualified_name(table_name.to_s)

          if options.key?(:name)
            provided_index = Utils.extract_schema_qualified_name(options[:name].to_s)

            options[:name] = provided_index.identifier
            table = PostgreSQL::Name.new(provided_index.schema, table.identifier) unless table.schema.present?

            if provided_index.schema.present? && table.schema != provided_index.schema
              raise ArgumentError.new("Index schema '#{provided_index.schema}' does not match table schema '#{table.schema}'")
            end
          end

          return if options[:if_exists] && !index_exists?(table_name, column_name, **options)

          index_to_remove = PostgreSQL::Name.new(table.schema, index_name_for_remove(table.to_s, column_name, options))

          execute "DROP INDEX #{index_algorithm(options[:algorithm])} #{quote_table_name(index_to_remove)}"
        end

        # Renames an index of a table. Raises error if length of new
        # index name is greater than allowed limit.
        def rename_index(table_name, old_name, new_name)
          validate_index_length!(table_name, new_name)

          schema, = extract_schema_qualified_name(table_name)
          execute "ALTER INDEX #{quote_table_name(schema) + '.' if schema}#{quote_column_name(old_name)} RENAME TO #{quote_table_name(new_name)}"
        end

        def index_name(table_name, options) # :nodoc:
          _schema, table_name = extract_schema_qualified_name(table_name.to_s)
          super
        end

        def add_foreign_key(from_table, to_table, **options)
          assert_valid_deferrable(options[:deferrable])

          super
        end

        def foreign_keys(table_name)
          scope = quoted_scope(table_name)
          fk_info = internal_exec_query(<<~SQL, "SCHEMA", allow_retry: true, materialize_transactions: false)
            SELECT t2.oid::regclass::text AS to_table, c.conname AS name, c.confupdtype AS on_update, c.confdeltype AS on_delete, c.convalidated AS valid, c.condeferrable AS deferrable, c.condeferred AS deferred, c.conrelid, c.confrelid,
              (
                SELECT array_agg(a.attname ORDER BY idx)
                FROM (
                  SELECT idx, c.conkey[idx] AS conkey_elem
                  FROM generate_subscripts(c.conkey, 1) AS idx
                ) indexed_conkeys
                JOIN pg_attribute a ON a.attrelid = t1.oid
                AND a.attnum = indexed_conkeys.conkey_elem
              ) AS conkey_names,
              (
                SELECT array_agg(a.attname ORDER BY idx)
                FROM (
                  SELECT idx, c.confkey[idx] AS confkey_elem
                  FROM generate_subscripts(c.confkey, 1) AS idx
                ) indexed_confkeys
                JOIN pg_attribute a ON a.attrelid = t2.oid
                AND a.attnum = indexed_confkeys.confkey_elem
              ) AS confkey_names
            FROM pg_constraint c
            JOIN pg_class t1 ON c.conrelid = t1.oid
            JOIN pg_class t2 ON c.confrelid = t2.oid
            JOIN pg_namespace n ON c.connamespace = n.oid
            WHERE c.contype = 'f'
              AND t1.relname = #{scope[:name]}
              AND n.nspname = #{scope[:schema]}
            ORDER BY c.conname
          SQL

          fk_info.map do |row|
            to_table = Utils.unquote_identifier(row["to_table"])

            column = decode_string_array(row["conkey_names"])
            primary_key = decode_string_array(row["confkey_names"])

            options = {
              column: column.size == 1 ? column.first : column,
              name: row["name"],
              primary_key: primary_key.size == 1 ? primary_key.first : primary_key
            }

            options[:on_delete] = extract_foreign_key_action(row["on_delete"])
            options[:on_update] = extract_foreign_key_action(row["on_update"])
            options[:deferrable] = extract_constraint_deferrable(row["deferrable"], row["deferred"])

            options[:validate] = row["valid"]

            ForeignKeyDefinition.new(table_name, to_table, options)
          end
        end

        def foreign_tables
          query_values(data_source_sql(type: "FOREIGN TABLE"), "SCHEMA")
        end

        def foreign_table_exists?(table_name)
          query_values(data_source_sql(table_name, type: "FOREIGN TABLE"), "SCHEMA").any? if table_name.present?
        end

        def check_constraints(table_name) # :nodoc:
          scope = quoted_scope(table_name)

          check_info = internal_exec_query(<<-SQL, "SCHEMA", allow_retry: true, materialize_transactions: false)
            SELECT conname, pg_get_constraintdef(c.oid, true) AS constraintdef, c.convalidated AS valid
            FROM pg_constraint c
            JOIN pg_class t ON c.conrelid = t.oid
            JOIN pg_namespace n ON n.oid = c.connamespace
            WHERE c.contype = 'c'
              AND t.relname = #{scope[:name]}
              AND n.nspname = #{scope[:schema]}
          SQL

          check_info.map do |row|
            options = {
              name: row["conname"],
              validate: row["valid"]
            }
            expression = row["constraintdef"][/CHECK \((.+)\)/m, 1]

            CheckConstraintDefinition.new(table_name, expression, options)
          end
        end

        # Returns an array of exclusion constraints for the given table.
        # The exclusion constraints are represented as ExclusionConstraintDefinition objects.
        def exclusion_constraints(table_name)
          scope = quoted_scope(table_name)

          exclusion_info = internal_exec_query(<<-SQL, "SCHEMA")
            SELECT conname, pg_get_constraintdef(c.oid) AS constraintdef, c.condeferrable, c.condeferred
            FROM pg_constraint c
            JOIN pg_class t ON c.conrelid = t.oid
            JOIN pg_namespace n ON n.oid = c.connamespace
            WHERE c.contype = 'x'
              AND t.relname = #{scope[:name]}
              AND n.nspname = #{scope[:schema]}
          SQL

          exclusion_info.map do |row|
            method_and_elements, predicate = row["constraintdef"].split(" WHERE ")
            method_and_elements_parts = method_and_elements.match(/EXCLUDE(?: USING (?<using>\S+))? \((?<expression>.+)\)/)
            predicate.remove!(/ DEFERRABLE(?: INITIALLY (?:IMMEDIATE|DEFERRED))?/) if predicate
            predicate = predicate.from(2).to(-3) if predicate # strip 2 opening and closing parentheses

            deferrable = extract_constraint_deferrable(row["condeferrable"], row["condeferred"])

            options = {
              name: row["conname"],
              using: method_and_elements_parts["using"].to_sym,
              where: predicate,
              deferrable: deferrable
            }

            ExclusionConstraintDefinition.new(table_name, method_and_elements_parts["expression"], options)
          end
        end

        # Returns an array of unique constraints for the given table.
        # The unique constraints are represented as UniqueConstraintDefinition objects.
        def unique_constraints(table_name)
          scope = quoted_scope(table_name)

          unique_info = internal_exec_query(<<~SQL, "SCHEMA", allow_retry: true, materialize_transactions: false)
            SELECT c.conname, c.conrelid, c.condeferrable, c.condeferred, pg_get_constraintdef(c.oid) AS constraintdef,
            (
              SELECT array_agg(a.attname ORDER BY idx)
              FROM (
                SELECT idx, c.conkey[idx] AS conkey_elem
                FROM generate_subscripts(c.conkey, 1) AS idx
              ) indexed_conkeys
              JOIN pg_attribute a ON a.attrelid = t.oid
              AND a.attnum = indexed_conkeys.conkey_elem
            ) AS conkey_names
            FROM pg_constraint c
            JOIN pg_class t ON c.conrelid = t.oid
            JOIN pg_namespace n ON n.oid = c.connamespace
            WHERE c.contype = 'u'
              AND t.relname = #{scope[:name]}
              AND n.nspname = #{scope[:schema]}
          SQL

          unique_info.map do |row|
            columns = decode_string_array(row["conkey_names"])

            nulls_not_distinct = row["constraintdef"].start_with?("UNIQUE NULLS NOT DISTINCT")
            deferrable = extract_constraint_deferrable(row["condeferrable"], row["condeferred"])

            options = {
              name: row["conname"],
              nulls_not_distinct: nulls_not_distinct,
              deferrable: deferrable
            }

            UniqueConstraintDefinition.new(table_name, columns, options)
          end
        end

        # Adds a new exclusion constraint to the table. +expression+ is a String
        # representation of a list of exclusion elements and operators.
        #
        #   add_exclusion_constraint :products, "price WITH =, availability_range WITH &&", using: :gist, name: "price_check"
        #
        # generates:
        #
        #   ALTER TABLE "products" ADD CONSTRAINT price_check EXCLUDE USING gist (price WITH =, availability_range WITH &&)
        #
        # The +options+ hash can include the following keys:
        # [<tt>:name</tt>]
        #   The constraint name. Defaults to <tt>excl_rails_<identifier></tt>.
        # [<tt>:deferrable</tt>]
        #   Specify whether or not the exclusion constraint should be deferrable. Valid values are +false+ or +:immediate+ or +:deferred+ to specify the default behavior. Defaults to +false+.
        # [<tt>:using</tt>]
        #   Specify which index method to use when creating this exclusion constraint (e.g. +:btree+, +:gist+ etc).
        # [<tt>:where</tt>]
        #   Specify an exclusion constraint on a subset of the table (internally PostgreSQL creates a partial index for this).
        def add_exclusion_constraint(table_name, expression, **options)
          options = exclusion_constraint_options(table_name, expression, options)
          at = create_alter_table(table_name)
          at.add_exclusion_constraint(expression, options)

          execute schema_creation.accept(at)
        end

        def exclusion_constraint_options(table_name, expression, options) # :nodoc:
          assert_valid_deferrable(options[:deferrable])

          options = options.dup
          options[:name] ||= exclusion_constraint_name(table_name, expression: expression, **options)
          options
        end

        # Removes the given exclusion constraint from the table.
        #
        #   remove_exclusion_constraint :products, name: "price_check"
        #
        # The +expression+ parameter will be ignored if present. It can be helpful
        # to provide this in a migration's +change+ method so it can be reverted.
        # In that case, +expression+ will be used by #add_exclusion_constraint.
        def remove_exclusion_constraint(table_name, expression = nil, **options)
          excl_name_to_delete = exclusion_constraint_for!(table_name, expression: expression, **options).name

          remove_constraint(table_name, excl_name_to_delete)
        end

        # Adds a new unique constraint to the table.
        #
        #   add_unique_constraint :sections, [:position], deferrable: :deferred, name: "unique_position", nulls_not_distinct: true
        #
        # generates:
        #
        #   ALTER TABLE "sections" ADD CONSTRAINT unique_position UNIQUE (position) DEFERRABLE INITIALLY DEFERRED
        #
        # If you want to change an existing unique index to deferrable, you can use :using_index to create deferrable unique constraints.
        #
        #   add_unique_constraint :sections, deferrable: :deferred, name: "unique_position", using_index: "index_sections_on_position"
        #
        # The +options+ hash can include the following keys:
        # [<tt>:name</tt>]
        #   The constraint name. Defaults to <tt>uniq_rails_<identifier></tt>.
        # [<tt>:deferrable</tt>]
        #   Specify whether or not the unique constraint should be deferrable. Valid values are +false+ or +:immediate+ or +:deferred+ to specify the default behavior. Defaults to +false+.
        # [<tt>:using_index</tt>]
        #   To specify an existing unique index name. Defaults to +nil+.
        # [<tt>:nulls_not_distinct</tt>]
        #   Create a unique constraint where NULLs are treated equally.
        #   Note: only supported by PostgreSQL version 15.0.0 and greater.
        def add_unique_constraint(table_name, column_name = nil, **options)
          options = unique_constraint_options(table_name, column_name, options)
          at = create_alter_table(table_name)
          at.add_unique_constraint(column_name, options)

          execute schema_creation.accept(at)
        end

        def unique_constraint_options(table_name, column_name, options) # :nodoc:
          assert_valid_deferrable(options[:deferrable])

          if column_name && options[:using_index]
            raise ArgumentError, "Cannot specify both column_name and :using_index options."
          end

          options = options.dup
          options[:name] ||= unique_constraint_name(table_name, column: column_name, **options)
          options
        end

        # Removes the given unique constraint from the table.
        #
        #   remove_unique_constraint :sections, name: "unique_position"
        #
        # The +column_name+ parameter will be ignored if present. It can be helpful
        # to provide this in a migration's +change+ method so it can be reverted.
        # In that case, +column_name+ will be used by #add_unique_constraint.
        def remove_unique_constraint(table_name, column_name = nil, **options)
          unique_name_to_delete = unique_constraint_for!(table_name, column: column_name, **options).name

          remove_constraint(table_name, unique_name_to_delete)
        end

        # Maps logical Rails types to PostgreSQL-specific data types.
        def type_to_sql(type, limit: nil, precision: nil, scale: nil, array: nil, enum_type: nil, **) # :nodoc:
          sql = \
            case type.to_s
            when "binary"
              # PostgreSQL doesn't support limits on binary (bytea) columns.
              # The hard limit is 1GB, because of a 32-bit size field, and TOAST.
              case limit
              when nil, 0..0x3fffffff; super(type)
              else raise ArgumentError, "No binary type has byte size #{limit}. The limit on binary can be at most 1GB - 1byte."
              end
            when "text"
              # PostgreSQL doesn't support limits on text columns.
              # The hard limit is 1GB, according to section 8.3 in the manual.
              case limit
              when nil, 0..0x3fffffff; super(type)
              else raise ArgumentError, "No text type has byte size #{limit}. The limit on text can be at most 1GB - 1byte."
              end
            when "integer"
              case limit
              when 1, 2; "smallint"
              when nil, 3, 4; "integer"
              when 5..8; "bigint"
              else raise ArgumentError, "No integer type has byte size #{limit}. Use a numeric with scale 0 instead."
              end
            when "enum"
              raise ArgumentError, "enum_type is required for enums" if enum_type.nil?

              enum_type
            else
              super
            end

          sql = "#{sql}[]" if array && type != :primary_key
          sql
        end

        # PostgreSQL requires the ORDER BY columns in the select list for distinct queries, and
        # requires that the ORDER BY include the distinct column.
        def columns_for_distinct(columns, orders) # :nodoc:
          order_columns = orders.compact_blank.map { |s|
            # Convert Arel node to string
            s = visitor.compile(s) unless s.is_a?(String)
            # Remove any ASC/DESC modifiers
            s.gsub(/\s+(?:ASC|DESC)\b/i, "")
             .gsub(/\s+NULLS\s+(?:FIRST|LAST)\b/i, "")
          }.compact_blank.map.with_index { |column, i| "#{column} AS alias_#{i}" }

          (order_columns << super).join(", ")
        end

        def update_table_definition(table_name, base) # :nodoc:
          PostgreSQL::Table.new(table_name, base)
        end

        def create_schema_dumper(options) # :nodoc:
          PostgreSQL::SchemaDumper.create(self, options)
        end

        # Validates the given constraint.
        #
        # Validates the constraint named +constraint_name+ on +accounts+.
        #
        #   validate_constraint :accounts, :constraint_name
        def validate_constraint(table_name, constraint_name)
          at = create_alter_table table_name
          at.validate_constraint constraint_name

          execute schema_creation.accept(at)
        end

        # Validates the given foreign key.
        #
        # Validates the foreign key on +accounts.branch_id+.
        #
        #   validate_foreign_key :accounts, :branches
        #
        # Validates the foreign key on +accounts.owner_id+.
        #
        #   validate_foreign_key :accounts, column: :owner_id
        #
        # Validates the foreign key named +special_fk_name+ on the +accounts+ table.
        #
        #   validate_foreign_key :accounts, name: :special_fk_name
        #
        # The +options+ hash accepts the same keys as SchemaStatements#add_foreign_key.
        def validate_foreign_key(from_table, to_table = nil, **options)
          fk_name_to_validate = foreign_key_for!(from_table, to_table: to_table, **options).name

          validate_constraint from_table, fk_name_to_validate
        end

        # Validates the given check constraint.
        #
        #   validate_check_constraint :products, name: "price_check"
        #
        # The +options+ hash accepts the same keys as {add_check_constraint}[rdoc-ref:ConnectionAdapters::SchemaStatements#add_check_constraint].
        def validate_check_constraint(table_name, **options)
          chk_name_to_validate = check_constraint_for!(table_name, **options).name

          validate_constraint table_name, chk_name_to_validate
        end

        def foreign_key_column_for(table_name, column_name) # :nodoc:
          _schema, table_name = extract_schema_qualified_name(table_name)
          super
        end

        def add_index_options(table_name, column_name, **options) # :nodoc:
          if (where = options[:where]) && table_exists?(table_name) && column_exists?(table_name, where)
            options[:where] = quote_column_name(where)
          end
          super
        end

        def quoted_include_columns_for_index(column_names) # :nodoc:
          return quote_column_name(column_names) if column_names.is_a?(Symbol)

          quoted_columns = column_names.each_with_object({}) do |name, result|
            result[name.to_sym] = quote_column_name(name).dup
          end
          add_options_for_index_columns(quoted_columns).values.join(", ")
        end

        def schema_creation  # :nodoc:
          PostgreSQL::SchemaCreation.new(self)
        end

        private
          def create_table_definition(name, **options)
            PostgreSQL::TableDefinition.new(self, name, **options)
          end

          def create_alter_table(name)
            PostgreSQL::AlterTable.new create_table_definition(name)
          end

          def new_column_from_field(table_name, field, _definitions)
            column_name, type, default, notnull, oid, fmod, collation, comment, identity, attgenerated = field
            type_metadata = fetch_type_metadata(column_name, type, oid.to_i, fmod.to_i)
            default_value = extract_value_from_default(default)

            if attgenerated.present?
              default_function = default
            else
              default_function = extract_default_function(default_value, default)
            end

            if match = default_function&.match(/\Anextval\('"?(?<sequence_name>.+_(?<suffix>seq\d*))"?'::regclass\)\z/)
              serial = sequence_name_from_parts(table_name, column_name, match[:suffix]) == match[:sequence_name]
            end

            PostgreSQL::Column.new(
              column_name,
              get_oid_type(oid.to_i, fmod.to_i, column_name, type),
              default_value,
              type_metadata,
              !notnull,
              default_function,
              collation: collation,
              comment: comment.presence,
              serial: serial,
              identity: identity.presence,
              generated: attgenerated
            )
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
            PostgreSQL::TypeMetadata.new(simple_type, oid: oid, fmod: fmod)
          end

          def sequence_name_from_parts(table_name, column_name, suffix)
            over_length = [table_name, column_name, suffix].sum(&:length) + 2 - max_identifier_length

            if over_length > 0
              column_name_length = [(max_identifier_length - suffix.length - 2) / 2, column_name.length].min
              over_length -= column_name.length - column_name_length
              column_name = column_name[0, column_name_length - [over_length, 0].min]
            end

            if over_length > 0
              table_name = table_name[0, table_name.length - over_length]
            end

            "#{table_name}_#{column_name}_#{suffix}"
          end

          def extract_foreign_key_action(specifier)
            case specifier
            when "c"; :cascade
            when "n"; :nullify
            when "r"; :restrict
            end
          end

          def assert_valid_deferrable(deferrable)
            return if !deferrable || %i(immediate deferred).include?(deferrable)

            raise ArgumentError, "deferrable must be `:immediate` or `:deferred`, got: `#{deferrable.inspect}`"
          end

          def extract_constraint_deferrable(deferrable, deferred)
            deferrable && (deferred ? :deferred : :immediate)
          end

          def reference_name_for_table(table_name)
            _schema, table_name = extract_schema_qualified_name(table_name.to_s)
            table_name.singularize
          end

          def add_column_for_alter(table_name, column_name, type, **options)
            return super unless options.key?(:comment)
            [super, Proc.new { change_column_comment(table_name, column_name, options[:comment]) }]
          end

          def change_column_for_alter(table_name, column_name, type, **options)
            change_col_def = build_change_column_definition(table_name, column_name, type, **options)
            sqls = [schema_creation.accept(change_col_def)]
            sqls << Proc.new { change_column_comment(table_name, column_name, options[:comment]) } if options.key?(:comment)
            sqls
          end

          def change_column_null_for_alter(table_name, column_name, null, default = nil)
            if default.nil?
              "ALTER COLUMN #{quote_column_name(column_name)} #{null ? 'DROP' : 'SET'} NOT NULL"
            else
              Proc.new { change_column_null(table_name, column_name, null, default) }
            end
          end

          def add_index_opclass(quoted_columns, **options)
            opclasses = options_for_index_columns(options[:opclass])
            quoted_columns.each do |name, column|
              column << " #{opclasses[name]}" if opclasses[name].present?
            end
          end

          def add_options_for_index_columns(quoted_columns, **options)
            quoted_columns = add_index_opclass(quoted_columns, **options)
            super
          end

          def exclusion_constraint_name(table_name, **options)
            options.fetch(:name) do
              expression = options.fetch(:expression)
              identifier = "#{table_name}_#{expression}_excl"
              hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)

              "excl_rails_#{hashed_identifier}"
            end
          end

          def exclusion_constraint_for(table_name, **options)
            excl_name = exclusion_constraint_name(table_name, **options)
            exclusion_constraints(table_name).detect { |excl| excl.name == excl_name }
          end

          def exclusion_constraint_for!(table_name, expression: nil, **options)
            exclusion_constraint_for(table_name, expression: expression, **options) ||
              raise(ArgumentError, "Table '#{table_name}' has no exclusion constraint for #{expression || options}")
          end

          def unique_constraint_name(table_name, **options)
            options.fetch(:name) do
              column_or_index = Array(options[:column] || options[:using_index]).map(&:to_s)
              identifier = "#{table_name}_#{column_or_index * '_and_'}_unique"
              hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)

              "uniq_rails_#{hashed_identifier}"
            end
          end

          def unique_constraint_for(table_name, **options)
            name = unique_constraint_name(table_name, **options) unless options.key?(:column)
            unique_constraints(table_name).detect { |unique_constraint| unique_constraint.defined_for?(name: name, **options) }
          end

          def unique_constraint_for!(table_name, column: nil, **options)
            unique_constraint_for(table_name, column: column, **options) ||
              raise(ArgumentError, "Table '#{table_name}' has no unique constraint for #{column || options}")
          end

          def data_source_sql(name = nil, type: nil)
            scope = quoted_scope(name, type: type)
            scope[:type] ||= "'r','v','m','p','f'" # (r)elation/table, (v)iew, (m)aterialized view, (p)artitioned table, (f)oreign table

            sql = +"SELECT c.relname FROM pg_class c LEFT JOIN pg_namespace n ON n.oid = c.relnamespace"
            sql << " WHERE n.nspname = #{scope[:schema]}"
            sql << " AND c.relname = #{scope[:name]}" if scope[:name]
            sql << " AND c.relkind IN (#{scope[:type]})"
            sql
          end

          def quoted_scope(name = nil, type: nil)
            schema, name = extract_schema_qualified_name(name)
            type = \
              case type
              when "BASE TABLE"
                "'r','p'"
              when "VIEW"
                "'v','m'"
              when "FOREIGN TABLE"
                "'f'"
              end
            scope = {}
            scope[:schema] = schema ? quote(schema) : "ANY (current_schemas(false))"
            scope[:name] = quote(name) if name
            scope[:type] = type if type
            scope
          end

          def extract_schema_qualified_name(string)
            name = Utils.extract_schema_qualified_name(string.to_s)
            [name.schema, name.identifier]
          end

          def decode_string_array(value)
            PG::TextDecoder::Array.new.decode(value)
          end
      end
    end
  end
end
