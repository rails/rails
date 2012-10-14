require 'active_record/connection_adapters/abstract_adapter'
require 'active_support/core_ext/object/blank'
require 'active_record/connection_adapters/statement_pool'
require 'arel/visitors/bind_visitor'

# Make sure we're using pg high enough for PGResult#values
gem 'pg', '~> 0.11'
require 'pg'

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects
    def self.postgresql_connection(config) # :nodoc:
      config = config.symbolize_keys
      host     = config[:host]
      port     = config[:port] || 5432
      username = config[:username].to_s if config[:username]
      password = config[:password].to_s if config[:password]

      if config.key?(:database)
        database = config[:database]
      else
        raise ArgumentError, "No database specified. Missing argument: database."
      end

      # The postgres drivers don't allow the creation of an unconnected PGconn object,
      # so just pass a nil connection object for the time being.
      ConnectionAdapters::PostgreSQLAdapter.new(nil, logger, [host, port, nil, nil, database, username, password], config)
    end
  end

  module ConnectionAdapters
    # PostgreSQL-specific extensions to column definitions in a table.
    class PostgreSQLColumn < Column #:nodoc:
      # Instantiates a new PostgreSQL column definition in a table.
      def initialize(name, default, sql_type = nil, null = true)
        super(name, self.class.extract_value_from_default(default), sql_type, null)
      end

      # :stopdoc:
      class << self
        attr_accessor :money_precision
        def string_to_time(string)
          return string unless String === string

          case string
          when 'infinity'  then 1.0 / 0.0
          when '-infinity' then -1.0 / 0.0
          else
            super
          end
        end
      end
      # :startdoc:

      private
        def extract_limit(sql_type)
          case sql_type
          when /^bigint/i;    8
          when /^smallint/i;  2
          else super
          end
        end

        # Extracts the scale from PostgreSQL-specific data types.
        def extract_scale(sql_type)
          # Money type has a fixed scale of 2.
          sql_type =~ /^money/ ? 2 : super
        end

        # Extracts the precision from PostgreSQL-specific data types.
        def extract_precision(sql_type)
          if sql_type == 'money'
            self.class.money_precision
          else
            super
          end
        end

        # Maps PostgreSQL-specific data types to logical Rails types.
        def simplified_type(field_type)
          case field_type
            # Numeric and monetary types
            when /^(?:real|double precision)$/
              :float
            # Monetary types
            when 'money'
              :decimal
            # Character types
            when /^(?:character varying|bpchar)(?:\(\d+\))?$/
              :string
            # Binary data types
            when 'bytea'
              :binary
            # Date/time types
            when /^timestamp with(?:out)? time zone$/
              :datetime
            when 'interval'
              :string
            # Geometric types
            when /^(?:point|line|lseg|box|"?path"?|polygon|circle)$/
              :string
            # Network address types
            when /^(?:cidr|inet|macaddr)$/
              :string
            # Bit strings
            when /^bit(?: varying)?(?:\(\d+\))?$/
              :string
            # XML type
            when 'xml'
              :xml
            # tsvector type
            when 'tsvector'
              :tsvector
            # Arrays
            when /^\D+\[\]$/
              :string
            # Object identifier types
            when 'oid'
              :integer
            # UUID type
            when 'uuid'
              :string
            # Small and big integer types
            when /^(?:small|big)int$/
              :integer
            # Pass through all types that are not specific to PostgreSQL.
            else
              super
          end
        end

        # Extracts the value from a PostgreSQL column default definition.
        def self.extract_value_from_default(default)
          case default
            # This is a performance optimization for Ruby 1.9.2 in development.
            # If the value is nil, we return nil straight away without checking
            # the regular expressions. If we check each regular expression,
            # Regexp#=== will call NilClass#to_str, which will trigger
            # method_missing (defined by whiny nil in ActiveSupport) which
            # makes this method very very slow.
            when NilClass
              nil
            # Numeric types
            when /\A\(?(-?\d+(\.\d*)?\)?)\z/
              $1
            # Character types
            when /\A\(?'(.*)'::.*\b(?:character varying|bpchar|text)\z/m
              $1
            # Binary data types
            when /\A'(.*)'::bytea\z/m
              $1
            # Date/time types
            when /\A'(.+)'::(?:time(?:stamp)? with(?:out)? time zone|date)\z/
              $1
            when /\A'(.*)'::interval\z/
              $1
            # Boolean type
            when 'true'
              true
            when 'false'
              false
            # Geometric types
            when /\A'(.*)'::(?:point|line|lseg|box|"?path"?|polygon|circle)\z/
              $1
            # Network address types
            when /\A'(.*)'::(?:cidr|inet|macaddr)\z/
              $1
            # Bit string types
            when /\AB'(.*)'::"?bit(?: varying)?"?\z/
              $1
            # XML type
            when /\A'(.*)'::xml\z/m
              $1
            # Arrays
            when /\A'(.*)'::"?\D+"?\[\]\z/
              $1
            # Object identifier types
            when /\A-?\d+\z/
              $1
            else
              # Anything else is blank, some user type, or some function
              # and we can't know the value of that, so return nil.
              nil
          end
        end
    end

    # The PostgreSQL adapter works both with the native C (http://ruby.scripting.ca/postgres/) and the pure
    # Ruby (available both as gem and from http://rubyforge.org/frs/?group_id=234&release_id=1944) drivers.
    #
    # Options:
    #
    # * <tt>:host</tt> - Defaults to "localhost".
    # * <tt>:port</tt> - Defaults to 5432.
    # * <tt>:username</tt> - Defaults to nothing.
    # * <tt>:password</tt> - Defaults to nothing.
    # * <tt>:database</tt> - The name of the database. No default, must be provided.
    # * <tt>:schema_search_path</tt> - An optional schema search path for the connection given
    #   as a string of comma-separated schema names. This is backward-compatible with the <tt>:schema_order</tt> option.
    # * <tt>:encoding</tt> - An optional client encoding that is used in a <tt>SET client_encoding TO
    #   <encoding></tt> call on the connection.
    # * <tt>:min_messages</tt> - An optional client min messages that is used in a
    #   <tt>SET client_min_messages TO <min_messages></tt> call on the connection.
    class PostgreSQLAdapter < AbstractAdapter
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        def xml(*args)
          options = args.extract_options!
          column(args[0], 'xml', options)
        end

        def tsvector(*args)
          options = args.extract_options!
          column(args[0], 'tsvector', options)
        end
      end

      ADAPTER_NAME = 'PostgreSQL'

      NATIVE_DATABASE_TYPES = {
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
        :boolean     => { :name => "boolean" },
        :xml         => { :name => "xml" },
        :tsvector    => { :name => "tsvector" }
      }

      # Returns 'PostgreSQL' as adapter name for identification purposes.
      def adapter_name
        ADAPTER_NAME
      end

      # Returns +true+, since this connection adapter supports prepared statement
      # caching.
      def supports_statement_cache?
        true
      end

      def supports_index_sort_order?
        true
      end

      class StatementPool < ConnectionAdapters::StatementPool
        def initialize(connection, max)
          super
          @counter = 0
          @cache   = Hash.new { |h,pid| h[pid] = {} }
        end

        def each(&block); cache.each(&block); end
        def key?(key);    cache.key?(key); end
        def [](key);      cache[key]; end
        def length;       cache.length; end

        def next_key
          "a#{@counter + 1}"
        end

        def []=(sql, key)
          while @max <= cache.size
            dealloc(cache.shift.last)
          end
          @counter += 1
          cache[sql] = key
        end

        def clear
          cache.each_value do |stmt_key|
            dealloc stmt_key
          end
          cache.clear
        end

        def delete(sql_key)
          dealloc cache[sql_key]
          cache.delete sql_key
        end

        private
        def cache
          @cache[$$]
        end

        def dealloc(key)
          @connection.query "DEALLOCATE #{key}" if connection_active?
        end

        def connection_active?
          @connection.status == PGconn::CONNECTION_OK
        rescue PGError
          false
        end
      end

      class BindSubstitution < Arel::Visitors::PostgreSQL # :nodoc:
        include Arel::Visitors::BindVisitor
      end

      # Initializes and connects a PostgreSQL adapter.
      def initialize(connection, logger, connection_parameters, config)
        super(connection, logger)

        if config.fetch(:prepared_statements) { true }
          @visitor = Arel::Visitors::PostgreSQL.new self
        else
          @visitor = BindSubstitution.new self
        end

        connection_parameters.delete :prepared_statements

        @connection_parameters, @config = connection_parameters, config

        # @local_tz is initialized as nil to avoid warnings when connect tries to use it
        @local_tz = nil
        @table_alias_length = nil

        connect
        @statements = StatementPool.new @connection,
                                        config.fetch(:statement_limit) { 1000 }

        if postgresql_version < 80200
          raise "Your version of PostgreSQL (#{postgresql_version}) is too old, please upgrade!"
        end

        @local_tz = execute('SHOW TIME ZONE', 'SCHEMA').first["TimeZone"]
      end

      # Clears the prepared statements cache.
      def clear_cache!
        @statements.clear
      end

      # Is this connection alive and ready for queries?
      def active?
        @connection.query 'SELECT 1'
        true
      rescue PGError
        false
      end

      # Close then reopen the connection.
      def reconnect!
        clear_cache!
        @connection.reset
        @open_transactions = 0
        configure_connection
      end

      def reset!
        clear_cache!
        super
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        clear_cache!
        @connection.close rescue nil
      end

      def native_database_types #:nodoc:
        NATIVE_DATABASE_TYPES
      end

      # Returns true, since this connection adapter supports migrations.
      def supports_migrations?
        true
      end

      # Does PostgreSQL support finding primary key on non-Active Record tables?
      def supports_primary_key? #:nodoc:
        true
      end

      # Enable standard-conforming strings if available.
      def set_standard_conforming_strings
        old, self.client_min_messages = client_min_messages, 'panic'
        execute('SET standard_conforming_strings = on', 'SCHEMA') rescue nil
      ensure
        self.client_min_messages = old
      end

      def supports_insert_with_returning?
        true
      end

      def supports_ddl_transactions?
        true
      end

      # Returns true, since this connection adapter supports savepoints.
      def supports_savepoints?
        true
      end

      # Returns true.
      def supports_explain?
        true
      end

      # Returns the configured supported identifier length supported by PostgreSQL
      def table_alias_length
        @table_alias_length ||= query('SHOW max_identifier_length')[0][0].to_i
      end

      # QUOTING ==================================================

      # Escapes binary strings for bytea input to the database.
      def escape_bytea(value)
        @connection.escape_bytea(value) if value
      end

      # Unescapes bytea output from a database to the binary string it represents.
      # NOTE: This is NOT an inverse of escape_bytea! This is only to be used
      #       on escaped binary output from database drive.
      def unescape_bytea(value)
        @connection.unescape_bytea(value) if value
      end

      # Quotes PostgreSQL-specific data types for SQL input.
      def quote(value, column = nil) #:nodoc:
        return super unless column

        case value
        when Float
          return super unless value.infinite? && column.type == :datetime
          "'#{value.to_s.downcase}'"
        when Numeric
          return super unless column.sql_type == 'money'
          # Not truly string input, so doesn't require (or allow) escape string syntax.
          "'#{value}'"
        when String
          case column.sql_type
          when 'bytea' then "'#{escape_bytea(value)}'"
          when 'xml'   then "xml '#{quote_string(value)}'"
          when /^bit/
            case value
            when /^[01]*$/      then "B'#{value}'" # Bit-string notation
            when /^[0-9A-F]*$/i then "X'#{value}'" # Hexadecimal notation
            end
          else
            super
          end
        else
          super
        end
      end

      def type_cast(value, column)
        return super unless column

        case value
        when String
          return super unless 'bytea' == column.sql_type
          { :value => value, :format => 1 }
        else
          super
        end
      end

      # Quotes strings for use in SQL input.
      def quote_string(s) #:nodoc:
        @connection.escape(s)
      end

      # Checks the following cases:
      #
      # - table_name
      # - "table.name"
      # - schema_name.table_name
      # - schema_name."table.name"
      # - "schema.name".table_name
      # - "schema.name"."table.name"
      def quote_table_name(name)
        schema, name_part = extract_pg_identifier_from_name(name.to_s)

        unless name_part
          quote_column_name(schema)
        else
          table_name, name_part = extract_pg_identifier_from_name(name_part)
          "#{quote_column_name(schema)}.#{quote_column_name(table_name)}"
        end
      end

      # Quotes column names for use in SQL queries.
      def quote_column_name(name) #:nodoc:
        PGconn.quote_ident(name.to_s)
      end

      # Quote date/time values for use in SQL input. Includes microseconds
      # if the value is a Time responding to usec.
      def quoted_date(value) #:nodoc:
        if value.acts_like?(:time) && value.respond_to?(:usec)
          "#{super}.#{sprintf("%06d", value.usec)}"
        else
          super
        end
      end

      # Set the authorized user for this session
      def session_auth=(user)
        clear_cache!
        exec_query "SET SESSION AUTHORIZATION #{user}"
      end

      # REFERENTIAL INTEGRITY ====================================

      def supports_disable_referential_integrity? #:nodoc:
        true
      end

      def disable_referential_integrity #:nodoc:
        if supports_disable_referential_integrity? then
          execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" }.join(";"))
        end
        yield
      ensure
        if supports_disable_referential_integrity? then
          execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL" }.join(";"))
        end
      end

      # DATABASE STATEMENTS ======================================

      def explain(arel, binds = [])
        sql = "EXPLAIN #{to_sql(arel, binds)}"
        ExplainPrettyPrinter.new.pp(exec_query(sql, 'EXPLAIN', binds))
      end

      class ExplainPrettyPrinter # :nodoc:
        # Pretty prints the result of a EXPLAIN in a way that resembles the output of the
        # PostgreSQL shell:
        #
        #                                     QUERY PLAN
        #   ------------------------------------------------------------------------------
        #    Nested Loop Left Join  (cost=0.00..37.24 rows=8 width=0)
        #      Join Filter: (posts.user_id = users.id)
        #      ->  Index Scan using users_pkey on users  (cost=0.00..8.27 rows=1 width=4)
        #            Index Cond: (id = 1)
        #      ->  Seq Scan on posts  (cost=0.00..28.88 rows=8 width=4)
        #            Filter: (posts.user_id = 1)
        #   (6 rows)
        #
        def pp(result)
          header = result.columns.first
          lines  = result.rows.map(&:first)

          # We add 2 because there's one char of padding at both sides, note
          # the extra hyphens in the example above.
          width = [header, *lines].map(&:length).max + 2

          pp = []

          pp << header.center(width).rstrip
          pp << '-' * width

          pp += lines.map {|line| " #{line}"}

          nrows = result.rows.length
          rows_label = nrows == 1 ? 'row' : 'rows'
          pp << "(#{nrows} #{rows_label})"

          pp.join("\n") + "\n"
        end
      end

      # Executes a SELECT query and returns an array of rows. Each row is an
      # array of field values.
      def select_rows(sql, name = nil)
        select_raw(sql, name).last
      end

      # Executes an INSERT query and returns the new record's ID
      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        unless pk
          # Extract the table from the insert sql. Yuck.
          table_ref = extract_table_ref_from_insert_sql(sql)
          pk = primary_key(table_ref) if table_ref
        end

        if pk
          select_value("#{sql} RETURNING #{quote_column_name(pk)}")
        else
          super
        end
      end
      alias :create :insert

      # create a 2D array representing the result set
      def result_as_array(res) #:nodoc:
        # check if we have any binary column and if they need escaping
        ftypes = Array.new(res.nfields) do |i|
          [i, res.ftype(i)]
        end

        rows = res.values
        return rows unless ftypes.any? { |_, x|
          x == BYTEA_COLUMN_TYPE_OID || x == MONEY_COLUMN_TYPE_OID
        }

        typehash = ftypes.group_by { |_, type| type }
        binaries = typehash[BYTEA_COLUMN_TYPE_OID] || []
        monies   = typehash[MONEY_COLUMN_TYPE_OID] || []

        rows.each do |row|
          # unescape string passed BYTEA field (OID == 17)
          binaries.each do |index, _|
            row[index] = unescape_bytea(row[index])
          end

          # If this is a money type column and there are any currency symbols,
          # then strip them off. Indeed it would be prettier to do this in
          # PostgreSQLColumn.string_to_decimal but would break form input
          # fields that call value_before_type_cast.
          monies.each do |index, _|
            data = row[index]
            # Because money output is formatted according to the locale, there are two
            # cases to consider (note the decimal separators):
            #  (1) $12,345,678.12
            #  (2) $12.345.678,12
            case data
            when /^-?\D+[\d,]+\.\d{2}$/  # (1)
              data.gsub!(/[^-\d.]/, '')
            when /^-?\D+[\d.]+,\d{2}$/  # (2)
              data.gsub!(/[^-\d,]/, '').sub!(/,/, '.')
            end
          end
        end
      end


      # Queries the database and returns the results in an Array-like object
      def query(sql, name = nil) #:nodoc:
        log(sql, name) do
          result_as_array @connection.async_exec(sql)
        end
      end

      # Executes an SQL statement, returning a PGresult object on success
      # or raising a PGError exception otherwise.
      def execute(sql, name = nil)
        log(sql, name) do
          @connection.async_exec(sql)
        end
      end

      def substitute_at(column, index)
        Arel::Nodes::BindParam.new "$#{index + 1}"
      end

      def exec_query(sql, name = 'SQL', binds = [])
        log(sql, name, binds) do
          result = binds.empty? ? exec_no_cache(sql, binds) :
                                  exec_cache(sql, binds)

          ret = ActiveRecord::Result.new(result.fields, result_as_array(result))
          result.clear
          return ret
        end
      end

      def exec_delete(sql, name = 'SQL', binds = [])
        log(sql, name, binds) do
          result = binds.empty? ? exec_no_cache(sql, binds) :
                                  exec_cache(sql, binds)
          affected = result.cmd_tuples
          result.clear
          affected
        end
      end
      alias :exec_update :exec_delete

      def sql_for_insert(sql, pk, id_value, sequence_name, binds)
        unless pk
          # Extract the table from the insert sql. Yuck.
          table_ref = extract_table_ref_from_insert_sql(sql)
          pk = primary_key(table_ref) if table_ref
        end

        sql = "#{sql} RETURNING #{quote_column_name(pk)}" if pk

        [sql, binds]
      end

      # Executes an UPDATE query and returns the number of affected tuples.
      def update_sql(sql, name = nil)
        super.cmd_tuples
      end

      # Begins a transaction.
      def begin_db_transaction
        execute "BEGIN"
      end

      # Commits a transaction.
      def commit_db_transaction
        execute "COMMIT"
      end

      # Aborts a transaction.
      def rollback_db_transaction
        execute "ROLLBACK"
      end

      def outside_transaction?
        @connection.transaction_status == PGconn::PQTRANS_IDLE
      end

      def create_savepoint
        execute("SAVEPOINT #{current_savepoint_name}")
      end

      def rollback_to_savepoint
        execute("ROLLBACK TO SAVEPOINT #{current_savepoint_name}")
      end

      def release_savepoint
        execute("RELEASE SAVEPOINT #{current_savepoint_name}")
      end

      # SCHEMA STATEMENTS ========================================

      # Drops the database specified on the +name+ attribute
      # and creates it again using the provided +options+.
      def recreate_database(name, options = {}) #:nodoc:
        drop_database(name)
        create_database(name, options)
      end

      # Create a new PostgreSQL database. Options include <tt>:owner</tt>, <tt>:template</tt>,
      # <tt>:encoding</tt>, <tt>:tablespace</tt>, and <tt>:connection_limit</tt> (note that MySQL uses
      # <tt>:charset</tt> while PostgreSQL uses <tt>:encoding</tt>).
      #
      # Example:
      #   create_database config[:database], config
      #   create_database 'foo_development', :encoding => 'unicode'
      def create_database(name, options = {})
        options = options.reverse_merge(:encoding => "utf8")

        option_string = options.symbolize_keys.sum do |key, value|
          case key
          when :owner
            " OWNER = \"#{value}\""
          when :template
            " TEMPLATE = \"#{value}\""
          when :encoding
            " ENCODING = '#{value}'"
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

          column_names.empty? ? nil : IndexDefinition.new(table_name, index_name, unique, column_names, [], orders)
        end.compact
      end

      # Returns the list of all column definitions for a table.
      def columns(table_name, name = nil)
        # Limit, precision, and scale are all handled by the superclass.
        column_definitions(table_name).collect do |column_name, type, default, notnull|
          PostgreSQLColumn.new(column_name, default, type, notnull == 'f')
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
        serial_sequence(table_name, pk || 'id').split('.').last
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
               pg_namespace  name,
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
          SELECT DISTINCT(attr.attname)
          FROM pg_attribute attr
          INNER JOIN pg_depend dep ON attr.attrelid = dep.refobjid AND attr.attnum = dep.refobjsubid
          INNER JOIN pg_constraint cons ON attr.attrelid = cons.conrelid AND attr.attnum = cons.conkey[1]
          WHERE cons.contype = 'p'
            AND dep.refobjid = '#{quote_table_name(table)}'::regclass
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
        when 'integer'
          return 'integer' unless limit

          case limit
            when 1, 2; 'smallint'
            when 3, 4; 'integer'
            when 5..8; 'bigint'
            else raise(ActiveRecordError, "No integer type has byte size #{limit}. Use a numeric with precision 0 instead.")
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
      #   distinct("posts.id", "posts.created_at desc")
      def distinct(columns, orders) #:nodoc:
        return "DISTINCT #{columns}" if orders.empty?

        # Construct a clean list of column names from the ORDER BY clause, removing
        # any ASC/DESC modifiers
        order_columns = orders.collect { |s| s.gsub(/\s+(ASC|DESC)\s*(NULLS\s+(FIRST|LAST)\s*)?/i, '') }
        order_columns.delete_if { |c| c.blank? }
        order_columns = order_columns.zip((0...order_columns.size).to_a).map { |s,i| "#{s} AS alias_#{i}" }

        "DISTINCT #{columns}, #{order_columns * ', '}"
      end

      module Utils
        extend self

        # Returns an array of <tt>[schema_name, table_name]</tt> extracted from +name+.
        # +schema_name+ is nil if not specified in +name+.
        # +schema_name+ and +table_name+ exclude surrounding quotes (regardless of whether provided in +name+)
        # +name+ supports the range of schema/table references understood by PostgreSQL, for example:
        #
        # * <tt>table_name</tt>
        # * <tt>"table.name"</tt>
        # * <tt>schema_name.table_name</tt>
        # * <tt>schema_name."table.name"</tt>
        # * <tt>"schema.name"."table name"</tt>
        def extract_schema_and_table(name)
          table, schema = name.scan(/[^".\s]+|"[^"]*"/)[0..1].collect{|m| m.gsub(/(^"|"$)/,'') }.reverse
          [schema, table]
        end
      end

      protected
        # Returns the version of the connected PostgreSQL server.
        def postgresql_version
          @connection.server_version
        end

        def translate_exception(exception, message)
          case exception.message
          when /duplicate key value violates unique constraint/
            RecordNotUnique.new(message, exception)
          when /violates foreign key constraint/
            InvalidForeignKey.new(message, exception)
          else
            super
          end
        end

      private
        FEATURE_NOT_SUPPORTED = "0A000" # :nodoc:

        def exec_no_cache(sql, binds)
          @connection.async_exec(sql)
        end

        def exec_cache(sql, binds)
          begin
            stmt_key = prepare_statement sql

            # Clear the queue
            @connection.get_last_result
            @connection.send_query_prepared(stmt_key, binds.map { |col, val|
              type_cast(val, col)
            })
            @connection.block
            @connection.get_last_result
          rescue PGError => e
            # Get the PG code for the failure.  Annoyingly, the code for
            # prepared statements whose return value may have changed is
            # FEATURE_NOT_SUPPORTED.  Check here for more details:
            # http://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/backend/utils/cache/plancache.c#l573
            code = e.result.result_error_field(PGresult::PG_DIAG_SQLSTATE)
            if FEATURE_NOT_SUPPORTED == code
              @statements.delete sql_key(sql)
              retry
            else
              raise e
            end
          end
        end

        # Returns the statement identifier for the client side cache
        # of statements
        def sql_key(sql)
          "#{schema_search_path}-#{sql}"
        end

        # Prepare the statement if it hasn't been prepared, return
        # the statement key.
        def prepare_statement(sql)
          sql_key = sql_key(sql)
          unless @statements.key? sql_key
            nextkey = @statements.next_key
            @connection.prepare nextkey, sql
            @statements[sql_key] = nextkey
          end
          @statements[sql_key]
        end

        # The internal PostgreSQL identifier of the money data type.
        MONEY_COLUMN_TYPE_OID = 790 #:nodoc:
        # The internal PostgreSQL identifier of the BYTEA data type.
        BYTEA_COLUMN_TYPE_OID = 17 #:nodoc:

        # Connects to a PostgreSQL server and sets up the adapter depending on the
        # connected server's characteristics.
        def connect
          @connection = PGconn.connect(*@connection_parameters)

          # Money type has a fixed precision of 10 in PostgreSQL 8.2 and below, and as of
          # PostgreSQL 8.3 it has a fixed precision of 19. PostgreSQLColumn.extract_precision
          # should know about this but can't detect it there, so deal with it here.
          PostgreSQLColumn.money_precision = (postgresql_version >= 80300) ? 19 : 10

          configure_connection
        end

        # Configures the encoding, verbosity, schema search path, and time zone of the connection.
        # This is called by #connect and should not be called manually.
        def configure_connection
          if @config[:encoding]
            @connection.set_client_encoding(@config[:encoding])
          end
          self.client_min_messages = @config[:min_messages] if @config[:min_messages]
          self.schema_search_path = @config[:schema_search_path] || @config[:schema_order]

          # Use standard-conforming strings if available so we don't have to do the E'...' dance.
          set_standard_conforming_strings

          # If using Active Record's time zone support configure the connection to return
          # TIMESTAMP WITH ZONE types in UTC.
          if ActiveRecord::Base.default_timezone == :utc
            execute("SET time zone 'UTC'", 'SCHEMA')
          elsif @local_tz
            execute("SET time zone '#{@local_tz}'", 'SCHEMA')
          end
        end

        # Returns the current ID of a table's sequence.
        def last_insert_id(sequence_name) #:nodoc:
          r = exec_query("SELECT currval('#{sequence_name}')", 'SQL')
          Integer(r.rows.first.first)
        end

        # Executes a SELECT query and returns the results, performing any data type
        # conversions that are required to be performed here instead of in PostgreSQLColumn.
        def select(sql, name = nil, binds = [])
          exec_query(sql, name, binds).to_a
        end

        def select_raw(sql, name = nil)
          res = execute(sql, name)
          results = result_as_array(res)
          fields = res.fields
          res.clear
          return fields, results
        end

        # Returns the list of a table's column names, data types, and default values.
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
        def column_definitions(table_name) #:nodoc:
          exec_query(<<-end_sql, 'SCHEMA').rows
            SELECT a.attname, format_type(a.atttypid, a.atttypmod),
                     pg_get_expr(d.adbin, d.adrelid), a.attnotnull, a.atttypid, a.atttypmod
              FROM pg_attribute a LEFT JOIN pg_attrdef d
                ON a.attrelid = d.adrelid AND a.attnum = d.adnum
             WHERE a.attrelid = '#{quote_table_name(table_name)}'::regclass
               AND a.attnum > 0 AND NOT a.attisdropped
             ORDER BY a.attnum
          end_sql
        end

        def extract_pg_identifier_from_name(name)
          match_data = name.start_with?('"') ? name.match(/\"([^\"]+)\"/) : name.match(/([^\.]+)/)

          if match_data
            rest = name[match_data[0].length, name.length]
            rest = rest[1, rest.length] if rest.start_with? "."
            [match_data[1], (rest.length > 0 ? rest : nil)]
          end
        end

        def extract_table_ref_from_insert_sql(sql)
          sql[/into\s+([^\(]*).*values\s*\(/i]
          $1.strip if $1
        end

        def table_definition
          TableDefinition.new(self)
        end
    end
  end
end
