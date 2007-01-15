require 'active_record/connection_adapters/abstract_adapter'

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects
    def self.postgresql_connection(config) # :nodoc:
      require_library_or_gem 'postgres' unless self.class.const_defined?(:PGconn)

      config = config.symbolize_keys
      host     = config[:host]
      port     = config[:port] || 5432
      username = config[:username].to_s
      password = config[:password].to_s

      min_messages = config[:min_messages]

      if config.has_key?(:database)
        database = config[:database]
      else
        raise ArgumentError, "No database specified. Missing argument: database."
      end

      pga = ConnectionAdapters::PostgreSQLAdapter.new(
        PGconn.connect(host, port, "", "", database, username, password), logger, config
      )

      PGconn.translate_results = false if PGconn.respond_to? :translate_results=

      pga.schema_search_path = config[:schema_search_path] || config[:schema_order]

      pga
    end
  end

  module ConnectionAdapters
    # The PostgreSQL adapter works both with the C-based (http://www.postgresql.jp/interfaces/ruby/) and the Ruby-base
    # (available both as gem and from http://rubyforge.org/frs/?group_id=234&release_id=1145) drivers.
    #
    # Options:
    #
    # * <tt>:host</tt> -- Defaults to localhost
    # * <tt>:port</tt> -- Defaults to 5432
    # * <tt>:username</tt> -- Defaults to nothing
    # * <tt>:password</tt> -- Defaults to nothing
    # * <tt>:database</tt> -- The name of the database. No default, must be provided.
    # * <tt>:schema_search_path</tt> -- An optional schema search path for the connection given as a string of comma-separated schema names.  This is backward-compatible with the :schema_order option.
    # * <tt>:encoding</tt> -- An optional client encoding that is using in a SET client_encoding TO <encoding> call on connection.
    # * <tt>:min_messages</tt> -- An optional client min messages that is using in a SET client_min_messages TO <min_messages> call on connection.
    # * <tt>:allow_concurrency</tt> -- If true, use async query methods so Ruby threads don't deadlock; otherwise, use blocking query methods.
    class PostgreSQLAdapter < AbstractAdapter
      def adapter_name
        'PostgreSQL'
      end

      def initialize(connection, logger, config = {})
        super(connection, logger)
        @config = config
        @async = config[:allow_concurrency]
        configure_connection
      end

      # Is this connection alive and ready for queries?
      def active?
        if @connection.respond_to?(:status)
          @connection.status == PGconn::CONNECTION_OK
        else
          @connection.query 'SELECT 1'
          true
        end
      # postgres-pr raises a NoMethodError when querying if no conn is available
      rescue PGError, NoMethodError
        false
      end

      # Close then reopen the connection.
      def reconnect!
        # TODO: postgres-pr doesn't have PGconn#reset.
        if @connection.respond_to?(:reset)
          @connection.reset
          configure_connection
        end
      end

      def disconnect!
        # Both postgres and postgres-pr respond to :close
        @connection.close rescue nil
      end

      def native_database_types
        {
          :primary_key => "serial primary key",
          :string      => { :name => "character varying", :limit => 255 },
          :text        => { :name => "text" },
          :integer     => { :name => "integer" },
          :float       => { :name => "float" },
          :decimal     => { :name => "decimal" },
          :datetime    => { :name => "timestamp" },
          :timestamp   => { :name => "timestamp" },
          :time        => { :name => "time" },
          :date        => { :name => "date" },
          :binary      => { :name => "bytea" },
          :boolean     => { :name => "boolean" }
        }
      end

      def supports_migrations?
        true
      end

      def table_alias_length
        63
      end

      # QUOTING ==================================================

      def quote(value, column = nil)
        if value.kind_of?(String) && column && column.type == :binary
          "'#{escape_bytea(value)}'"
        else
          super
        end
      end

      def quote_column_name(name)
        %("#{name}")
      end

      def quoted_date(value)
        value.strftime("%Y-%m-%d %H:%M:%S.#{sprintf("%06d", value.usec)}")
      end


      # DATABASE STATEMENTS ======================================

      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        execute(sql, name)
        table = sql.split(" ", 4)[2]
        id_value || last_insert_id(table, sequence_name || default_sequence_name(table, pk))
      end

      def query(sql, name = nil) #:nodoc:
        log(sql, name) do
          if @async
            @connection.async_query(sql)
          else
            @connection.query(sql)
          end
        end
      end

      def execute(sql, name = nil) #:nodoc:
        log(sql, name) do
          if @async
            @connection.async_exec(sql)
          else
            @connection.exec(sql)
          end
        end
      end

      def update(sql, name = nil) #:nodoc:
        execute(sql, name).cmdtuples
      end

      def begin_db_transaction #:nodoc:
        execute "BEGIN"
      end

      def commit_db_transaction #:nodoc:
        execute "COMMIT"
      end

      def rollback_db_transaction #:nodoc:
        execute "ROLLBACK"
      end

      # SCHEMA STATEMENTS ========================================

      # Return the list of all tables in the schema search path.
      def tables(name = nil) #:nodoc:
        schemas = schema_search_path.split(/,/).map { |p| quote(p) }.join(',')
        query(<<-SQL, name).map { |row| row[0] }
          SELECT tablename
            FROM pg_tables
           WHERE schemaname IN (#{schemas})
        SQL
      end

      def indexes(table_name, name = nil) #:nodoc:
        result = query(<<-SQL, name)
          SELECT i.relname, d.indisunique, a.attname
            FROM pg_class t, pg_class i, pg_index d, pg_attribute a
           WHERE i.relkind = 'i'
             AND d.indexrelid = i.oid
             AND d.indisprimary = 'f'
             AND t.oid = d.indrelid
             AND t.relname = '#{table_name}'
             AND a.attrelid = t.oid
             AND ( d.indkey[0]=a.attnum OR d.indkey[1]=a.attnum
                OR d.indkey[2]=a.attnum OR d.indkey[3]=a.attnum
                OR d.indkey[4]=a.attnum OR d.indkey[5]=a.attnum
                OR d.indkey[6]=a.attnum OR d.indkey[7]=a.attnum
                OR d.indkey[8]=a.attnum OR d.indkey[9]=a.attnum )
          ORDER BY i.relname
        SQL

        current_index = nil
        indexes = []

        result.each do |row|
          if current_index != row[0]
            indexes << IndexDefinition.new(table_name, row[0], row[1] == "t", [])
            current_index = row[0]
          end

          indexes.last.columns << row[2]
        end

        indexes
      end

      def columns(table_name, name = nil) #:nodoc:
        column_definitions(table_name).collect do |name, type, default, notnull, typmod|
          # typmod now unused as limit, precision, scale all handled by superclass
          Column.new(name, default_value(default), translate_field_type(type), notnull == "f")
        end
      end

      # Set the schema search path to a string of comma-separated schema names.
      # Names beginning with $ are quoted (e.g. $user => '$user')
      # See http://www.postgresql.org/docs/8.0/interactive/ddl-schemas.html
      def schema_search_path=(schema_csv) #:nodoc:
        if schema_csv
          execute "SET search_path TO #{schema_csv}"
          @schema_search_path = nil
        end
      end

      def schema_search_path #:nodoc:
        @schema_search_path ||= query('SHOW search_path')[0][0]
      end

      def default_sequence_name(table_name, pk = nil)
        default_pk, default_seq = pk_and_sequence_for(table_name)
        default_seq || "#{table_name}_#{pk || default_pk || 'id'}_seq"
      end

      # Resets sequence to the max value of the table's pk if present.
      def reset_pk_sequence!(table, pk = nil, sequence = nil)
        unless pk and sequence
          default_pk, default_sequence = pk_and_sequence_for(table)
          pk ||= default_pk
          sequence ||= default_sequence
        end
        if pk
          if sequence
            select_value <<-end_sql, 'Reset sequence'
              SELECT setval('#{sequence}', (SELECT COALESCE(MAX(#{pk})+(SELECT increment_by FROM #{sequence}), (SELECT min_value FROM #{sequence})) FROM #{table}), false)
            end_sql
          else
            @logger.warn "#{table} has primary key #{pk} with no default sequence" if @logger
          end
        end
      end

      # Find a table's primary key and sequence.
      def pk_and_sequence_for(table)
        # First try looking for a sequence with a dependency on the
        # given table's primary key.
        result = query(<<-end_sql, 'PK and serial sequence')[0]
          SELECT attr.attname, name.nspname, seq.relname
          FROM pg_class      seq,
               pg_attribute  attr,
               pg_depend     dep,
               pg_namespace  name,
               pg_constraint cons
          WHERE seq.oid           = dep.objid
            AND seq.relnamespace  = name.oid
            AND seq.relkind       = 'S'
            AND attr.attrelid     = dep.refobjid
            AND attr.attnum       = dep.refobjsubid
            AND attr.attrelid     = cons.conrelid
            AND attr.attnum       = cons.conkey[1]
            AND cons.contype      = 'p'
            AND dep.refobjid      = '#{table}'::regclass
        end_sql

        if result.nil? or result.empty?
          # If that fails, try parsing the primary key's default value.
          # Support the 7.x and 8.0 nextval('foo'::text) as well as
          # the 8.1+ nextval('foo'::regclass).
          # TODO: assumes sequence is in same schema as table.
          result = query(<<-end_sql, 'PK and custom sequence')[0]
            SELECT attr.attname, name.nspname, split_part(def.adsrc, '''', 2)
            FROM pg_class       t
            JOIN pg_namespace   name ON (t.relnamespace = name.oid)
            JOIN pg_attribute   attr ON (t.oid = attrelid)
            JOIN pg_attrdef     def  ON (adrelid = attrelid AND adnum = attnum)
            JOIN pg_constraint  cons ON (conrelid = adrelid AND adnum = conkey[1])
            WHERE t.oid = '#{table}'::regclass
              AND cons.contype = 'p'
              AND def.adsrc ~* 'nextval'
          end_sql
        end
        # check for existence of . in sequence name as in public.foo_sequence.  if it does not exist, return unqualified sequence
        # We cannot qualify unqualified sequences, as rails doesn't qualify any table access, using the search path
        [result.first, result.last]
      rescue
        nil
      end

      def rename_table(name, new_name)
        execute "ALTER TABLE #{name} RENAME TO #{new_name}"
      end

      def add_column(table_name, column_name, type, options = {})
        default = options[:default]
        notnull = options[:null] == false

        # Add the column.
        execute("ALTER TABLE #{table_name} ADD COLUMN #{column_name} #{type_to_sql(type, options[:limit])}")

        # Set optional default. If not null, update nulls to the new default.
        if options_include_default?(options)
          change_column_default(table_name, column_name, default)
          if notnull
            execute("UPDATE #{table_name} SET #{column_name}=#{quote(default, options[:column])} WHERE #{column_name} IS NULL")
          end
        end

        if notnull
          execute("ALTER TABLE #{table_name} ALTER #{column_name} SET NOT NULL")
        end
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        begin
          execute "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} TYPE #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        rescue ActiveRecord::StatementInvalid
          # This is PG7, so we use a more arcane way of doing it.
          begin_db_transaction
          add_column(table_name, "#{column_name}_ar_tmp", type, options)
          execute "UPDATE #{table_name} SET #{column_name}_ar_tmp = CAST(#{column_name} AS #{type_to_sql(type, options[:limit], options[:precision], options[:scale])})"
          remove_column(table_name, column_name)
          rename_column(table_name, "#{column_name}_ar_tmp", column_name)
          commit_db_transaction
        end

        if options_include_default?(options)
          change_column_default(table_name, column_name, options[:default])
        end
      end

      def change_column_default(table_name, column_name, default) #:nodoc:
        execute "ALTER TABLE #{table_name} ALTER COLUMN #{quote_column_name(column_name)} SET DEFAULT #{quote(default)}"
      end

      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        execute "ALTER TABLE #{table_name} RENAME COLUMN #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
      end

      def remove_index(table_name, options) #:nodoc:
        execute "DROP INDEX #{index_name(table_name, options)}"
      end

      def type_to_sql(type, limit = nil, precision = nil, scale = nil) #:nodoc:
        return super unless type.to_s == 'integer'

        if limit.nil? || limit == 4
          'integer'
        elsif limit < 4
          'smallint'
        else
          'bigint'
        end
      end
      
      # SELECT DISTINCT clause for a given set of columns and a given ORDER BY clause.
      #
      # PostgreSQL requires the ORDER BY columns in the select list for distinct queries, and
      # requires that the ORDER BY include the distinct column.
      #
      #   distinct("posts.id", "posts.created_at desc")
      def distinct(columns, order_by)
        return "DISTINCT #{columns}" if order_by.blank?

        # construct a clean list of column names from the ORDER BY clause, removing
        # any asc/desc modifiers
        order_columns = order_by.split(',').collect { |s| s.split.first }
        order_columns.delete_if &:blank?
        order_columns = order_columns.zip((0...order_columns.size).to_a).map { |s,i| "#{s} AS alias_#{i}" }

        # return a DISTINCT ON() clause that's distinct on the columns we want but includes
        # all the required columns for the ORDER BY to work properly
        sql = "DISTINCT ON (#{columns}) #{columns}, "
        sql << order_columns * ', '
      end
      
      # ORDER BY clause for the passed order option.
      # 
      # PostgreSQL does not allow arbitrary ordering when using DISTINCT ON, so we work around this
      # by wrapping the sql as a sub-select and ordering in that query.
      def add_order_by_for_association_limiting!(sql, options)
        return sql if options[:order].blank?
        
        order = options[:order].split(',').collect { |s| s.strip }.reject(&:blank?)
        order.map! { |s| 'DESC' if s =~ /\bdesc$/i }
        order = order.zip((0...order.size).to_a).map { |s,i| "id_list.alias_#{i} #{s}" }.join(', ')
        
        sql.replace "SELECT * FROM (#{sql}) AS id_list ORDER BY #{order}"
      end

      private
        BYTEA_COLUMN_TYPE_OID = 17
        NUMERIC_COLUMN_TYPE_OID = 1700
        TIMESTAMPOID = 1114
        TIMESTAMPTZOID = 1184

        def configure_connection
          if @config[:encoding]
            execute("SET client_encoding TO '#{@config[:encoding]}'")
          end
          if @config[:min_messages]
            execute("SET client_min_messages TO '#{@config[:min_messages]}'")
          end
        end

        def last_insert_id(table, sequence_name)
          Integer(select_value("SELECT currval('#{sequence_name}')"))
        end

        def select(sql, name = nil)
          res = execute(sql, name)
          results = res.result
          rows = []
          if results.length > 0
            fields = res.fields
            results.each do |row|
              hashed_row = {}
              row.each_index do |cel_index|
                column = row[cel_index]

                case res.type(cel_index)
                  when BYTEA_COLUMN_TYPE_OID
                    column = unescape_bytea(column)
                  when TIMESTAMPTZOID, TIMESTAMPOID
                    column = cast_to_time(column)
                  when NUMERIC_COLUMN_TYPE_OID
                    column = column.to_d if column.respond_to?(:to_d)
                end

                hashed_row[fields[cel_index]] = column
              end
              rows << hashed_row
            end
          end
          res.clear
          return rows
        end

        def escape_bytea(s)
          if PGconn.respond_to? :escape_bytea
            self.class.send(:define_method, :escape_bytea) do |s|
              PGconn.escape_bytea(s) if s
            end
          else
            self.class.send(:define_method, :escape_bytea) do |s|
              if s
                result = ''
                s.each_byte { |c| result << sprintf('\\\\%03o', c) }
                result
              end
            end
          end
          escape_bytea(s)
        end

        def unescape_bytea(s)
          if PGconn.respond_to? :unescape_bytea
            self.class.send(:define_method, :unescape_bytea) do |s|
              PGconn.unescape_bytea(s) if s
            end
          else
            self.class.send(:define_method, :unescape_bytea) do |s|
              if s
                result = ''
                i, max = 0, s.size
                while i < max
                  char = s[i]
                  if char == ?\\
                    if s[i+1] == ?\\
                      char = ?\\
                      i += 1
                    else
                      char = s[i+1..i+3].oct
                      i += 3
                    end
                  end
                  result << char
                  i += 1
                end
                result
              end
            end
          end
          unescape_bytea(s)
        end

        # Query a table's column names, default values, and types.
        #
        # The underlying query is roughly:
        #  SELECT column.name, column.type, default.value
        #    FROM column LEFT JOIN default
        #      ON column.table_id = default.table_id
        #     AND column.num = default.column_num
        #   WHERE column.table_id = get_table_id('table_name')
        #     AND column.num > 0
        #     AND NOT column.is_dropped
        #   ORDER BY column.num
        #
        # If the table name is not prefixed with a schema, the database will
        # take the first match from the schema search path.
        #
        # Query implementation notes:
        #  - format_type includes the column size constraint, e.g. varchar(50)
        #  - ::regclass is a function that gives the id for a table name
        def column_definitions(table_name)
          query <<-end_sql
            SELECT a.attname, format_type(a.atttypid, a.atttypmod), d.adsrc, a.attnotnull
              FROM pg_attribute a LEFT JOIN pg_attrdef d
                ON a.attrelid = d.adrelid AND a.attnum = d.adnum
             WHERE a.attrelid = '#{table_name}'::regclass
               AND a.attnum > 0 AND NOT a.attisdropped
             ORDER BY a.attnum
          end_sql
        end

        # Translate PostgreSQL-specific types into simplified SQL types.
        # These are special cases; standard types are handled by
        # ConnectionAdapters::Column#simplified_type.
        def translate_field_type(field_type)
          # Match the beginning of field_type since it may have a size constraint on the end.
          case field_type
            # PostgreSQL array data types.
            when /\[\]$/i  then 'string'
            when /^timestamp/i    then 'datetime'
            when /^real|^money/i  then 'float'
            when /^interval/i     then 'string'
            # geometric types (the line type is currently not implemented in postgresql)
            when /^(?:point|lseg|box|"?path"?|polygon|circle)/i  then 'string'
            when /^bytea/i        then 'binary'
            else field_type       # Pass through standard types.
          end
        end

        def default_value(value)
          # Boolean types
          return "t" if value =~ /true/i
          return "f" if value =~ /false/i

          # Char/String/Bytea type values
          return $1 if value =~ /^'(.*)'::(bpchar|text|character varying|bytea)$/

          # Numeric values
          return value if value =~ /^-?[0-9]+(\.[0-9]*)?/

          # Fixed dates / times
          return $1 if value =~ /^'(.+)'::(date|timestamp)/

          # Anything else is blank, some user type, or some function
          # and we can't know the value of that, so return nil.
          return nil
        end

        # Only needed for DateTime instances
        def cast_to_time(value)
          return value unless value.class == DateTime
          v = value
          time_array = [v.year, v.month, v.day, v.hour, v.min, v.sec, v.usec]
          Time.send(Base.default_timezone, *time_array) rescue nil
        end
    end
  end
end
