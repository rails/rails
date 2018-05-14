# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
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
          options = { encoding: "utf8" }.merge!(options.symbolize_keys)

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

        def drop_table(table_name, options = {}) # :nodoc:
          execute "DROP TABLE#{' IF EXISTS' if options[:if_exists]} #{quote_table_name(table_name)}#{' CASCADE' if options[:force] == :cascade}"
        end

        # Returns true if schema exists.
        def schema_exists?(name)
          query_value("SELECT COUNT(*) FROM pg_namespace WHERE nspname = #{quote(name)}", "SCHEMA").to_i > 0
        end

        # Verifies existence of an index with a given name.
        def index_name_exists?(table_name, index_name)
          table = quoted_scope(table_name)
          index = quoted_scope(index_name)

          query_value(<<-SQL, "SCHEMA").to_i > 0
            SELECT COUNT(*)
            FROM pg_class t
            INNER JOIN pg_index d ON t.oid = d.indrelid
            INNER JOIN pg_class i ON d.indexrelid = i.oid
            LEFT JOIN pg_namespace n ON n.oid = i.relnamespace
            WHERE i.relkind = 'i'
              AND i.relname = #{index[:name]}
              AND t.relname = #{table[:name]}
              AND n.nspname = #{index[:schema]}
          SQL
        end

        # Returns an array of indexes for the given table.
        def indexes(table_name) # :nodoc:
          scope = quoted_scope(table_name)

          result = query(<<-SQL, "SCHEMA")
            SELECT distinct i.relname, d.indisunique, d.indkey, pg_get_indexdef(d.indexrelid), t.oid,
                            pg_catalog.obj_description(i.oid, 'pg_class') AS comment
            FROM pg_class t
            INNER JOIN pg_index d ON t.oid = d.indrelid
            INNER JOIN pg_class i ON d.indexrelid = i.oid
            LEFT JOIN pg_namespace n ON n.oid = i.relnamespace
            WHERE i.relkind = 'i'
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
            oid = row[4]
            comment = row[5]

            using, expressions, where = inddef.scan(/ USING (\w+?) \((.+?)\)(?: WHERE (.+))?\z/m).flatten

            orders = {}
            opclasses = {}

            if indkey.include?(0)
              columns = expressions
            else
              columns = Hash[query(<<~SQL, "SCHEMA")].values_at(*indkey).compact
                SELECT a.attnum, a.attname
                FROM pg_attribute a
                WHERE a.attrelid = #{oid}
                AND a.attnum IN (#{indkey.join(",")})
              SQL

              # add info on sort order (only desc order is explicitly specified, asc is the default)
              # and non-default opclasses
              expressions.scan(/(?<column>\w+)\s?(?<opclass>\w+_ops)?\s?(?<desc>DESC)?\s?(?<nulls>NULLS (?:FIRST|LAST))?/).each do |column, opclass, desc, nulls|
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
              comment: comment.presence
            )
          end
        end

        def table_options(table_name) # :nodoc:
          if comment = table_comment(table_name)
            { comment: comment }
          end
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

        # Returns the current database name.
        def current_database
          query_value("SELECT current_database()", "SCHEMA")
        end

        # Returns the current schema name.
        def current_schema
          query_value("SELECT current_schema", "SCHEMA")
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
          query_values(<<-SQL, "SCHEMA")
            SELECT nspname
              FROM pg_namespace
             WHERE nspname !~ '^pg_.*'
               AND nspname NOT IN ('information_schema')
             ORDER by nspname;
          SQL
        end

        # Creates a schema for the given schema name.
        def create_schema(schema_name)
          execute "CREATE SCHEMA #{quote_schema_name(schema_name)}"
        end

        # Drops the schema for the given schema name.
        def drop_schema(schema_name, options = {})
          execute "DROP SCHEMA#{' IF EXISTS' if options[:if_exists]} #{quote_schema_name(schema_name)} CASCADE"
        end

        # Sets the schema search path to a string of comma-separated schema names.
        # Names beginning with $ have to be quoted (e.g. $user => '$user').
        # See: https://www.postgresql.org/docs/current/static/ddl-schemas.html
        #
        # This should be not be called manually but set in database.yml.
        def schema_search_path=(schema_csv)
          if schema_csv
            execute("SET search_path TO #{schema_csv}", "SCHEMA")
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
          execute("SET client_min_messages TO '#{level}'", "SCHEMA")
        end

        # Returns the sequence name for a table's primary key or some other specified key.
        def default_sequence_name(table_name, pk = "id") #:nodoc:
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
        def set_pk_sequence!(table, value) #:nodoc:
          pk, sequence = pk_and_sequence_for(table)

          if pk
            if sequence
              quoted_sequence = quote_table_name(sequence)

              query_value("SELECT setval(#{quote(quoted_sequence)}, #{value})", "SCHEMA")
            else
              @logger.warn "#{table} has primary key #{pk} with no default sequence." if @logger
            end
          end
        end

        # Resets the sequence of a table's primary key to the maximum value.
        def reset_pk_sequence!(table, pk = nil, sequence = nil) #:nodoc:
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
              if postgresql_version >= 100000
                minvalue = query_value("SELECT seqmin FROM pg_sequence WHERE seqrelid = #{quote(quoted_sequence)}::regclass", "SCHEMA")
              else
                minvalue = query_value("SELECT min_value FROM #{quoted_sequence}", "SCHEMA")
              end
            end

            query_value("SELECT setval(#{quote(quoted_sequence)}, #{max_pk ? max_pk : minvalue}, #{max_pk ? true : false})", "SCHEMA")
          end
        end

        # Returns a table's primary key and belonging sequence.
        def pk_and_sequence_for(table) #:nodoc:
          # First try looking for a sequence with a dependency on the
          # given table's primary key.
          result = query(<<-end_sql, "SCHEMA")[0]
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
          end_sql

          if result.nil? || result.empty?
            result = query(<<-end_sql, "SCHEMA")[0]
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
          query_values(<<~SQL, "SCHEMA")
            SELECT a.attname
              FROM (
                     SELECT indrelid, indkey, generate_subscripts(indkey, 1) idx
                       FROM pg_index
                      WHERE indrelid = #{quote(quote_table_name(table_name))}::regclass
                        AND indisprimary
                   ) i
              JOIN pg_attribute a
                ON a.attrelid = i.indrelid
               AND a.attnum = i.indkey[i.idx]
             ORDER BY i.idx
          SQL
        end

        def bulk_change_table(table_name, operations)
          sql_fragments = []
          non_combinable_operations = []

          operations.each do |command, args|
            table, arguments = args.shift, args
            method = :"#{command}_for_alter"

            if respond_to?(method, true)
              sqls, procs = Array(send(method, table, *arguments)).partition { |v| v.is_a?(String) }
              sql_fragments << sqls
              non_combinable_operations.concat(procs)
            else
              execute "ALTER TABLE #{quote_table_name(table_name)} #{sql_fragments.join(", ")}" unless sql_fragments.empty?
              non_combinable_operations.each(&:call)
              sql_fragments = []
              non_combinable_operations = []
              send(command, table, *arguments)
            end
          end

          execute "ALTER TABLE #{quote_table_name(table_name)} #{sql_fragments.join(", ")}" unless sql_fragments.empty?
          non_combinable_operations.each(&:call)
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
          if pk
            idx = "#{table_name}_pkey"
            new_idx = "#{new_name}_pkey"
            execute "ALTER INDEX #{quote_table_name(idx)} RENAME TO #{quote_table_name(new_idx)}"
            if seq && seq.identifier == "#{table_name}_#{pk}_seq"
              new_seq = "#{new_name}_#{pk}_seq"
              execute "ALTER TABLE #{seq.quoted} RENAME TO #{quote_table_name(new_seq)}"
            end
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
          sqls, procs = Array(change_column_for_alter(table_name, column_name, type, options)).partition { |v| v.is_a?(String) }
          execute "ALTER TABLE #{quote_table_name(table_name)} #{sqls.join(", ")}"
          procs.each(&:call)
        end

        # Changes the default value of a table column.
        def change_column_default(table_name, column_name, default_or_changes) # :nodoc:
          execute "ALTER TABLE #{quote_table_name(table_name)} #{change_column_default_for_alter(table_name, column_name, default_or_changes)}"
        end

        def change_column_null(table_name, column_name, null, default = nil) #:nodoc:
          clear_cache!
          unless null || default.nil?
            column = column_for(table_name, column_name)
            execute "UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote_default_expression(default, column)} WHERE #{quote_column_name(column_name)} IS NULL" if column
          end
          execute "ALTER TABLE #{quote_table_name(table_name)} #{change_column_null_for_alter(table_name, column_name, null, default)}"
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
          index_name, index_type, index_columns_and_opclasses, index_options, index_algorithm, index_using, comment = add_index_options(table_name, column_name, options)
          execute("CREATE #{index_type} INDEX #{index_algorithm} #{quote_column_name(index_name)} ON #{quote_table_name(table_name)} #{index_using} (#{index_columns_and_opclasses})#{index_options}").tap do
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
          scope = quoted_scope(table_name)
          fk_info = exec_query(<<~SQL, "SCHEMA")
            SELECT t2.oid::regclass::text AS to_table, a1.attname AS column, a2.attname AS primary_key, c.conname AS name, c.confupdtype AS on_update, c.confdeltype AS on_delete, c.convalidated AS valid
            FROM pg_constraint c
            JOIN pg_class t1 ON c.conrelid = t1.oid
            JOIN pg_class t2 ON c.confrelid = t2.oid
            JOIN pg_attribute a1 ON a1.attnum = c.conkey[1] AND a1.attrelid = t1.oid
            JOIN pg_attribute a2 ON a2.attnum = c.confkey[1] AND a2.attrelid = t2.oid
            JOIN pg_namespace t3 ON c.connamespace = t3.oid
            WHERE c.contype = 'f'
              AND t1.relname = #{scope[:name]}
              AND t3.nspname = #{scope[:schema]}
            ORDER BY c.conname
          SQL

          fk_info.map do |row|
            options = {
              column: row["column"],
              name: row["name"],
              primary_key: row["primary_key"]
            }

            options[:on_delete] = extract_foreign_key_action(row["on_delete"])
            options[:on_update] = extract_foreign_key_action(row["on_update"])
            options[:validate] = row["valid"]

            ForeignKeyDefinition.new(table_name, row["to_table"], options)
          end
        end

        def foreign_tables
          query_values(data_source_sql(type: "FOREIGN TABLE"), "SCHEMA")
        end

        def foreign_table_exists?(table_name)
          query_values(data_source_sql(table_name, type: "FOREIGN TABLE"), "SCHEMA").any? if table_name.present?
        end

        # Maps logical Rails types to PostgreSQL-specific data types.
        def type_to_sql(type, limit: nil, precision: nil, scale: nil, array: nil, **) # :nodoc:
          sql = \
            case type.to_s
            when "binary"
              # PostgreSQL doesn't support limits on binary (bytea) columns.
              # The hard limit is 1GB, because of a 32-bit size field, and TOAST.
              case limit
              when nil, 0..0x3fffffff; super(type)
              else raise(ActiveRecordError, "No binary type has byte size #{limit}.")
              end
            when "text"
              # PostgreSQL doesn't support limits on text columns.
              # The hard limit is 1GB, according to section 8.3 in the manual.
              case limit
              when nil, 0..0x3fffffff; super(type)
              else raise(ActiveRecordError, "The limit on text can be at most 1GB - 1byte.")
              end
            when "integer"
              case limit
              when 1, 2; "smallint"
              when nil, 3, 4; "integer"
              when 5..8; "bigint"
              else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with scale 0 instead.")
              end
            else
              super
            end

          sql = "#{sql}[]" if array && type != :primary_key
          sql
        end

        # PostgreSQL requires the ORDER BY columns in the select list for distinct queries, and
        # requires that the ORDER BY include the distinct column.
        def columns_for_distinct(columns, orders) #:nodoc:
          order_columns = orders.reject(&:blank?).map { |s|
              # Convert Arel node to string
              s = s.to_sql unless s.is_a?(String)
              # Remove any ASC/DESC modifiers
              s.gsub(/\s+(?:ASC|DESC)\b/i, "")
               .gsub(/\s+NULLS\s+(?:FIRST|LAST)\b/i, "")
            }.reject(&:blank?).map.with_index { |column, i| "#{column} AS alias_#{i}" }

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
          return unless supports_validate_constraints?

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
        def validate_foreign_key(from_table, options_or_to_table = {})
          return unless supports_validate_constraints?

          fk_name_to_validate = foreign_key_for!(from_table, options_or_to_table).name

          validate_constraint from_table, fk_name_to_validate
        end

        private
          def schema_creation
            PostgreSQL::SchemaCreation.new(self)
          end

          def create_table_definition(*args)
            PostgreSQL::TableDefinition.new(*args)
          end

          def create_alter_table(name)
            PostgreSQL::AlterTable.new create_table_definition(name)
          end

          def new_column_from_field(table_name, field)
            column_name, type, default, notnull, oid, fmod, collation, comment = field
            type_metadata = fetch_type_metadata(column_name, type, oid.to_i, fmod.to_i)
            default_value = extract_value_from_default(default)
            default_function = extract_default_function(default_value, default)

            PostgreSQLColumn.new(
              column_name,
              default_value,
              type_metadata,
              !notnull,
              table_name,
              default_function,
              collation,
              comment: comment.presence,
              max_identifier_length: max_identifier_length
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
            PostgreSQLTypeMetadata.new(simple_type, oid: oid, fmod: fmod)
          end

          def extract_foreign_key_action(specifier)
            case specifier
            when "c"; :cascade
            when "n"; :nullify
            when "r"; :restrict
            end
          end

          def change_column_sql(table_name, column_name, type, options = {})
            quoted_column_name = quote_column_name(column_name)
            sql_type = type_to_sql(type, options)
            sql = "ALTER COLUMN #{quoted_column_name} TYPE #{sql_type}".dup
            if options[:collation]
              sql << " COLLATE \"#{options[:collation]}\""
            end
            if options[:using]
              sql << " USING #{options[:using]}"
            elsif options[:cast_as]
              cast_as_type = type_to_sql(options[:cast_as], options)
              sql << " USING CAST(#{quoted_column_name} AS #{cast_as_type})"
            end

            sql
          end

          def change_column_for_alter(table_name, column_name, type, options = {})
            sqls = [change_column_sql(table_name, column_name, type, options)]
            sqls << change_column_default_for_alter(table_name, column_name, options[:default]) if options.key?(:default)
            sqls << change_column_null_for_alter(table_name, column_name, options[:null], options[:default]) if options.key?(:null)
            sqls << Proc.new { change_column_comment(table_name, column_name, options[:comment]) } if options.key?(:comment)
            sqls
          end


          # Changes the default value of a table column.
          def change_column_default_for_alter(table_name, column_name, default_or_changes) # :nodoc:
            column = column_for(table_name, column_name)
            return unless column

            default = extract_new_default_value(default_or_changes)
            alter_column_query = "ALTER COLUMN #{quote_column_name(column_name)} %s"
            if default.nil?
              # <tt>DEFAULT NULL</tt> results in the same behavior as <tt>DROP DEFAULT</tt>. However, PostgreSQL will
              # cast the default to the columns type, which leaves us with a default like "default NULL::character varying".
              alter_column_query % "DROP DEFAULT"
            else
              alter_column_query % "SET DEFAULT #{quote_default_expression(default, column)}"
            end
          end

          def change_column_null_for_alter(table_name, column_name, null, default = nil) #:nodoc:
            "ALTER #{quote_column_name(column_name)} #{null ? 'DROP' : 'SET'} NOT NULL"
          end

          def add_timestamps_for_alter(table_name, options = {})
            [add_column_for_alter(table_name, :created_at, :datetime, options), add_column_for_alter(table_name, :updated_at, :datetime, options)]
          end

          def remove_timestamps_for_alter(table_name, options = {})
            [remove_column_for_alter(table_name, :updated_at), remove_column_for_alter(table_name, :created_at)]
          end

          def add_index_opclass(quoted_columns, **options)
            opclasses = options_for_index_columns(options[:opclass])
            quoted_columns.each do |name, column|
              column << " #{opclasses[name]}" if opclasses[name].present?
            end
          end

          def add_options_for_index_columns(quoted_columns, **options)
            quoted_columns = add_index_opclass(quoted_columns, options)
            super
          end

          def data_source_sql(name = nil, type: nil)
            scope = quoted_scope(name, type: type)
            scope[:type] ||= "'r','v','m','f'" # (r)elation/table, (v)iew, (m)aterialized view, (f)oreign table

            sql = "SELECT c.relname FROM pg_class c LEFT JOIN pg_namespace n ON n.oid = c.relnamespace".dup
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
                "'r'"
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
      end
    end
  end
end
