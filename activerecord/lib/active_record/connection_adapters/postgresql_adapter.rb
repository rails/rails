require 'active_record/connection_adapters/abstract_adapter'
require 'active_record/connection_adapters/statement_pool'
require 'active_record/connection_adapters/postgresql/oid'
require 'active_record/connection_adapters/postgresql/cast'
require 'active_record/connection_adapters/postgresql/array_parser'
require 'active_record/connection_adapters/postgresql/quoting'
require 'active_record/connection_adapters/postgresql/schema_statements'
require 'active_record/connection_adapters/postgresql/database_statements'
require 'active_record/connection_adapters/postgresql/referential_integrity'
require 'arel/visitors/bind_visitor'

# Make sure we're using pg high enough for PGResult#values
gem 'pg', '~> 0.11'
require 'pg'

require 'ipaddr'

module ActiveRecord
  module ConnectionHandling
    VALID_CONN_PARAMS = [:host, :hostaddr, :port, :dbname, :user, :password, :connect_timeout,
                         :client_encoding, :options, :application_name, :fallback_application_name,
                         :keepalives, :keepalives_idle, :keepalives_interval, :keepalives_count,
                         :tty, :sslmode, :requiressl, :sslcert, :sslkey, :sslrootcert, :sslcrl,
                         :requirepeer, :krbsrvname, :gsslib, :service]

    # Establishes a connection to the database that's used by all Active Record objects
    def postgresql_connection(config) # :nodoc:
      conn_params = config.symbolize_keys

      conn_params.delete_if { |_, v| v.nil? }

      # Map ActiveRecords param names to PGs.
      conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
      conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

      # Forward only valid config params to PGconn.connect.
      conn_params.keep_if { |k, _| VALID_CONN_PARAMS.include?(k) }

      # The postgres drivers don't allow the creation of an unconnected PGconn object,
      # so just pass a nil connection object for the time being.
      ConnectionAdapters::PostgreSQLAdapter.new(nil, logger, conn_params, config)
    end
  end

  module ConnectionAdapters
    # PostgreSQL-specific extensions to column definitions in a table.
    class PostgreSQLColumn < Column #:nodoc:
      attr_accessor :array
      # Instantiates a new PostgreSQL column definition in a table.
      def initialize(name, default, oid_type, sql_type = nil, null = true)
        @oid_type = oid_type
        if sql_type =~ /\[\]$/
          @array = true
          super(name, self.class.extract_value_from_default(default), sql_type[0..sql_type.length - 3], null)
        else
          @array = false
          super(name, self.class.extract_value_from_default(default), sql_type, null)
        end
      end

      # :stopdoc:
      class << self
        include ConnectionAdapters::PostgreSQLColumn::Cast
        include ConnectionAdapters::PostgreSQLColumn::ArrayParser
        attr_accessor :money_precision
      end
      # :startdoc:

      # Extracts the value from a PostgreSQL column default definition.
      def self.extract_value_from_default(default)
        # This is a performance optimization for Ruby 1.9.2 in development.
        # If the value is nil, we return nil straight away without checking
        # the regular expressions. If we check each regular expression,
        # Regexp#=== will call NilClass#to_str, which will trigger
        # method_missing (defined by whiny nil in ActiveSupport) which
        # makes this method very very slow.
        return default unless default

        case default
          when /\A'(.*)'::(num|date|tstz|ts|int4|int8)range\z/m
            $1
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
          # Hstore
          when /\A'(.*)'::hstore\z/
            $1
          # JSON
          when /\A'(.*)'::json\z/
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

      def type_cast(value)
        return if value.nil?
        return super if encoded?

        @oid_type.type_cast value
      end

      private

        def extract_limit(sql_type)
          case sql_type
          when /^bigint/i;    8
          when /^smallint/i;  2
          when /^timestamp/i; nil
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
          elsif sql_type =~ /timestamp/i
            $1.to_i if sql_type =~ /\((\d+)\)/
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
          when 'hstore'
            :hstore
          when 'ltree'
            :ltree
          # Network address types
          when 'inet'
            :inet
          when 'cidr'
            :cidr
          when 'macaddr'
            :macaddr
          # Character types
          when /^(?:character varying|bpchar)(?:\(\d+\))?$/
            :string
          # Binary data types
          when 'bytea'
            :binary
          # Date/time types
          when /^timestamp with(?:out)? time zone$/
            :datetime
          when /^interval(?:|\(\d+\))$/
            :string
          # Geometric types
          when /^(?:point|line|lseg|box|"?path"?|polygon|circle)$/
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
            :uuid
          # JSON type
          when 'json'
            :json
          # Small and big integer types
          when /^(?:small|big)int$/
            :integer
          when /(num|date|tstz|ts|int4|int8)range$/
            field_type.to_sym
          # Pass through all types that are not specific to PostgreSQL.
          else
            super
          end
        end
    end

    # The PostgreSQL adapter works with the native C (https://bitbucket.org/ged/ruby-pg) driver.
    #
    # Options:
    #
    # * <tt>:host</tt> - Defaults to a Unix-domain socket in /tmp. On machines without Unix-domain sockets,
    #   the default is to connect to localhost.
    # * <tt>:port</tt> - Defaults to 5432.
    # * <tt>:username</tt> - Defaults to be the same as the operating system name of the user running the application.
    # * <tt>:password</tt> - Password to be used if the server demands password authentication.
    # * <tt>:database</tt> - Defaults to be the same as the user name.
    # * <tt>:schema_search_path</tt> - An optional schema search path for the connection given
    #   as a string of comma-separated schema names. This is backward-compatible with the <tt>:schema_order</tt> option.
    # * <tt>:encoding</tt> - An optional client encoding that is used in a <tt>SET client_encoding TO
    #   <encoding></tt> call on the connection.
    # * <tt>:min_messages</tt> - An optional client min messages that is used in a
    #   <tt>SET client_min_messages TO <min_messages></tt> call on the connection.
    # * <tt>:variables</tt> - An optional hash of additional parameters that
    #   will be used in <tt>SET SESSION key = val</tt> calls on the connection.
    # * <tt>:insert_returning</tt> - An optional boolean to control the use or <tt>RETURNING</tt> for <tt>INSERT</tt> statements
    #   defaults to true.
    #
    # Any further options are used as connection parameters to libpq. See
    # http://www.postgresql.org/docs/9.1/static/libpq-connect.html for the
    # list of parameters.
    #
    # In addition, default connection parameters of libpq can be set per environment variables.
    # See http://www.postgresql.org/docs/9.1/static/libpq-envars.html .
    class PostgreSQLAdapter < AbstractAdapter
      class ColumnDefinition < ActiveRecord::ConnectionAdapters::ColumnDefinition
        attr_accessor :array
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        def xml(*args)
          options = args.extract_options!
          column(args[0], 'xml', options)
        end

        def tsvector(*args)
          options = args.extract_options!
          column(args[0], 'tsvector', options)
        end

        def int4range(name, options = {})
          column(name, 'int4range', options)
        end

        def int8range(name, options = {})
          column(name, 'int8range', options)
        end

        def tsrange(name, options = {})
          column(name, 'tsrange', options)
        end

        def tstzrange(name, options = {})
          column(name, 'tstzrange', options)
        end

        def numrange(name, options = {})
          column(name, 'numrange', options)
        end

        def daterange(name, options = {})
          column(name, 'daterange', options)
        end

        def hstore(name, options = {})
          column(name, 'hstore', options)
        end

        def ltree(name, options = {})
          column(name, 'ltree', options)
        end

        def inet(name, options = {})
          column(name, 'inet', options)
        end

        def cidr(name, options = {})
          column(name, 'cidr', options)
        end

        def macaddr(name, options = {})
          column(name, 'macaddr', options)
        end

        def uuid(name, options = {})
          column(name, 'uuid', options)
        end

        def json(name, options = {})
          column(name, 'json', options)
        end

        def column(name, type = nil, options = {})
          super
          column = self[name]
          column.array = options[:array]

          self
        end

        private

        def new_column_definition(base, name, type)
          definition = ColumnDefinition.new base, name, type
          @columns << definition
          @columns_hash[name] = definition
          definition
        end
      end

      ADAPTER_NAME = 'PostgreSQL'

      NATIVE_DATABASE_TYPES = {
        primary_key: "serial primary key",
        string:      { name: "character varying", limit: 255 },
        text:        { name: "text" },
        integer:     { name: "integer" },
        float:       { name: "float" },
        decimal:     { name: "decimal" },
        datetime:    { name: "timestamp" },
        timestamp:   { name: "timestamp" },
        time:        { name: "time" },
        date:        { name: "date" },
        daterange:   { name: "daterange" },
        numrange:    { name: "numrange" },
        tsrange:     { name: "tsrange" },
        tstzrange:   { name: "tstzrange" },
        int4range:   { name: "int4range" },
        int8range:   { name: "int8range" },
        binary:      { name: "bytea" },
        boolean:     { name: "boolean" },
        xml:         { name: "xml" },
        tsvector:    { name: "tsvector" },
        hstore:      { name: "hstore" },
        inet:        { name: "inet" },
        cidr:        { name: "cidr" },
        macaddr:     { name: "macaddr" },
        uuid:        { name: "uuid" },
        json:        { name: "json" },
        ltree:       { name: "ltree" }
      }

      include Quoting
      include ReferentialIntegrity
      include SchemaStatements
      include DatabaseStatements

      # Returns 'PostgreSQL' as adapter name for identification purposes.
      def adapter_name
        ADAPTER_NAME
      end

      # Adds `:array` option to the default set provided by the
      # AbstractAdapter
      def prepare_column_options(column, types)
        spec = super
        spec[:array] = 'true' if column.respond_to?(:array) && column.array
        spec
      end

      # Adds `:array` as a valid migration key
      def migration_keys
        super + [:array]
      end

      # Returns +true+, since this connection adapter supports prepared statement
      # caching.
      def supports_statement_cache?
        true
      end

      def supports_index_sort_order?
        true
      end

      def supports_partial_index?
        true
      end

      def supports_transaction_isolation?
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
            @cache[Process.pid]
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

        if self.class.type_cast_config_to_boolean(config.fetch(:prepared_statements) { true })
          @visitor = Arel::Visitors::PostgreSQL.new self
        else
          @visitor = BindSubstitution.new self
        end

        @connection_parameters, @config = connection_parameters, config

        # @local_tz is initialized as nil to avoid warnings when connect tries to use it
        @local_tz = nil
        @table_alias_length = nil

        connect
        @statements = StatementPool.new @connection,
                                        self.class.type_cast_config_to_integer(config.fetch(:statement_limit) { 1000 })

        if postgresql_version < 80200
          raise "Your version of PostgreSQL (#{postgresql_version}) is too old, please upgrade!"
        end

        initialize_type_map
        @local_tz = execute('SHOW TIME ZONE', 'SCHEMA').first["TimeZone"]
        @use_insert_returning = @config.key?(:insert_returning) ? self.class.type_cast_config_to_boolean(@config[:insert_returning]) : true
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
        super
        @connection.reset
        configure_connection
      end

      def reset!
        clear_cache!
        super
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        super
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

      # Returns true if pg > 9.2
      def supports_extensions?
        postgresql_version >= 90200
      end

      # Range datatypes weren't introduced until PostgreSQL 9.2
      def supports_ranges?
        postgresql_version >= 90200
      end

      def enable_extension(name)
        exec_query("CREATE EXTENSION IF NOT EXISTS #{name}").tap {
          reload_type_map
        }
      end

      def disable_extension(name)
        exec_query("DROP EXTENSION IF EXISTS #{name} CASCADE").tap {
          reload_type_map
        }
      end

      def extension_enabled?(name)
        if supports_extensions?
          res = exec_query "SELECT EXISTS(SELECT * FROM pg_available_extensions WHERE name = '#{name}' AND installed_version IS NOT NULL)",
            'SCHEMA'
          res.column_types['exists'].type_cast res.rows.first.first
        end
      end

      def extensions
        if supports_extensions?
          res = exec_query "SELECT extname from pg_extension", "SCHEMA"
          res.rows.map { |r| res.column_types['extname'].type_cast r.first }
        else
          super
        end
      end

      # Returns the configured supported identifier length supported by PostgreSQL
      def table_alias_length
        @table_alias_length ||= query('SHOW max_identifier_length', 'SCHEMA')[0][0].to_i
      end

      def add_column_options!(sql, options)
        if options[:array] || options[:column].try(:array)
          sql << '[]'
        end
        super
      end

      # Set the authorized user for this session
      def session_auth=(user)
        clear_cache!
        exec_query "SET SESSION AUTHORIZATION #{user}"
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

      def use_insert_returning?
        @use_insert_returning
      end

      protected

        # Returns the version of the connected PostgreSQL server.
        def postgresql_version
          @connection.server_version
        end

        # See http://www.postgresql.org/docs/9.1/static/errcodes-appendix.html
        FOREIGN_KEY_VIOLATION = "23503"
        UNIQUE_VIOLATION      = "23505"

        def translate_exception(exception, message)
          case exception.result.try(:error_field, PGresult::PG_DIAG_SQLSTATE)
          when UNIQUE_VIOLATION
            RecordNotUnique.new(message, exception)
          when FOREIGN_KEY_VIOLATION
            InvalidForeignKey.new(message, exception)
          else
            super
          end
        end

      private

        def reload_type_map
          OID::TYPE_MAP.clear
          initialize_type_map
        end

        def initialize_type_map
          result = execute('SELECT oid, typname, typelem, typdelim, typinput FROM pg_type', 'SCHEMA')
          leaves, nodes = result.partition { |row| row['typelem'] == '0' }

          # populate the leaf nodes
          leaves.find_all { |row| OID.registered_type? row['typname'] }.each do |row|
            OID::TYPE_MAP[row['oid'].to_i] = OID::NAMES[row['typname']]
          end

          arrays, nodes = nodes.partition { |row| row['typinput'] == 'array_in' }

          # populate composite types
          nodes.find_all { |row| OID::TYPE_MAP.key? row['typelem'].to_i }.each do |row|
            vector = OID::Vector.new row['typdelim'], OID::TYPE_MAP[row['typelem'].to_i]
            OID::TYPE_MAP[row['oid'].to_i] = vector
          end

          # populate array types
          arrays.find_all { |row| OID::TYPE_MAP.key? row['typelem'].to_i }.each do |row|
            array = OID::Array.new  OID::TYPE_MAP[row['typelem'].to_i]
            OID::TYPE_MAP[row['oid'].to_i] = array
          end
        end

        FEATURE_NOT_SUPPORTED = "0A000" # :nodoc:

        def exec_no_cache(sql, binds)
          @connection.async_exec(sql)
        end

        def exec_cache(sql, binds)
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
          begin
            code = e.result.result_error_field(PGresult::PG_DIAG_SQLSTATE)
          rescue
            raise e
          end
          if FEATURE_NOT_SUPPORTED == code
            @statements.delete sql_key(sql)
            retry
          else
            raise e
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
          @connection = PGconn.connect(@connection_parameters)

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
          self.client_min_messages = @config[:min_messages] || 'warning'
          self.schema_search_path = @config[:schema_search_path] || @config[:schema_order]

          # Use standard-conforming strings if available so we don't have to do the E'...' dance.
          set_standard_conforming_strings

          # If using Active Record's time zone support configure the connection to return
          # TIMESTAMP WITH ZONE types in UTC.
          # (SET TIME ZONE does not use an equals sign like other SET variables)
          if ActiveRecord::Base.default_timezone == :utc
            execute("SET time zone 'UTC'", 'SCHEMA')
          elsif @local_tz
            execute("SET time zone '#{@local_tz}'", 'SCHEMA')
          end

          # SET statements from :variables config hash
          # http://www.postgresql.org/docs/8.3/static/sql-set.html
          variables = @config[:variables] || {}
          variables.map do |k, v|
            if v == ':default' || v == :default
              # Sets the value to the global or compile default
              execute("SET SESSION #{k.to_s} TO DEFAULT", 'SCHEMA')
            elsif !v.nil?
              execute("SET SESSION #{k.to_s} TO #{quote(v)}", 'SCHEMA')
            end
          end
        end

        # Returns the current ID of a table's sequence.
        def last_insert_id(sequence_name) #:nodoc:
          Integer(last_insert_id_value(sequence_name))
        end

        def last_insert_id_value(sequence_name)
          last_insert_id_result(sequence_name).rows.first.first
        end

        def last_insert_id_result(sequence_name) #:nodoc:
          exec_query("SELECT currval('#{sequence_name}')", 'SQL')
        end

        # Executes a SELECT query and returns the results, performing any data type
        # conversions that are required to be performed here instead of in PostgreSQLColumn.
        def select(sql, name = nil, binds = [])
          exec_query(sql, name, binds)
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
