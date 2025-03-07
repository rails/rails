# frozen_string_literal: true

gem "pg", "~> 1.1"
require "pg"

require "active_support/core_ext/object/try"
require "active_record/connection_adapters/abstract_adapter"
require "active_record/connection_adapters/statement_pool"
require "active_record/connection_adapters/postgresql/column"
require "active_record/connection_adapters/postgresql/database_statements"
require "active_record/connection_adapters/postgresql/explain_pretty_printer"
require "active_record/connection_adapters/postgresql/oid"
require "active_record/connection_adapters/postgresql/quoting"
require "active_record/connection_adapters/postgresql/referential_integrity"
require "active_record/connection_adapters/postgresql/schema_creation"
require "active_record/connection_adapters/postgresql/schema_definitions"
require "active_record/connection_adapters/postgresql/schema_dumper"
require "active_record/connection_adapters/postgresql/schema_statements"
require "active_record/connection_adapters/postgresql/type_metadata"
require "active_record/connection_adapters/postgresql/utils"

module ActiveRecord
  module ConnectionAdapters
    # = Active Record PostgreSQL Adapter
    #
    # The PostgreSQL adapter works with the native C (https://github.com/ged/ruby-pg) driver.
    #
    # Options:
    #
    # * <tt>:host</tt> - Defaults to a Unix-domain socket in /tmp. On machines without Unix-domain sockets,
    #   the default is to connect to localhost.
    # * <tt>:port</tt> - Defaults to 5432.
    # * <tt>:username</tt> - Defaults to be the same as the operating system name of the user running the application.
    # * <tt>:password</tt> - Password to be used if the server demands password authentication.
    # * <tt>:database</tt> - Defaults to be the same as the username.
    # * <tt>:schema_search_path</tt> - An optional schema search path for the connection given
    #   as a string of comma-separated schema names. This is backward-compatible with the <tt>:schema_order</tt> option.
    # * <tt>:encoding</tt> - An optional client encoding that is used in a <tt>SET client_encoding TO
    #   <encoding></tt> call on the connection.
    # * <tt>:min_messages</tt> - An optional client min messages that is used in a
    #   <tt>SET client_min_messages TO <min_messages></tt> call on the connection.
    # * <tt>:variables</tt> - An optional hash of additional parameters that
    #   will be used in <tt>SET SESSION key = val</tt> calls on the connection.
    # * <tt>:insert_returning</tt> - An optional boolean to control the use of <tt>RETURNING</tt> for <tt>INSERT</tt> statements
    #   defaults to true.
    #
    # Any further options are used as connection parameters to libpq. See
    # https://www.postgresql.org/docs/current/static/libpq-connect.html for the
    # list of parameters.
    #
    # In addition, default connection parameters of libpq can be set per environment variables.
    # See https://www.postgresql.org/docs/current/static/libpq-envars.html .
    class PostgreSQLAdapter < AbstractAdapter
      ADAPTER_NAME = "PostgreSQL"

      class << self
        def new_client(conn_params)
          PG.connect(**conn_params)
        rescue ::PG::Error => error
          if conn_params && conn_params[:dbname] == "postgres"
            raise ActiveRecord::ConnectionNotEstablished, error.message
          elsif conn_params && conn_params[:dbname] && error.message.include?(conn_params[:dbname])
            raise ActiveRecord::NoDatabaseError.db_error(conn_params[:dbname])
          elsif conn_params && conn_params[:user] && error.message.include?(conn_params[:user])
            raise ActiveRecord::DatabaseConnectionError.username_error(conn_params[:user])
          elsif conn_params && conn_params[:host] && error.message.include?(conn_params[:host])
            raise ActiveRecord::DatabaseConnectionError.hostname_error(conn_params[:host])
          else
            raise ActiveRecord::ConnectionNotEstablished, error.message
          end
        end

        def dbconsole(config, options = {})
          pg_config = config.configuration_hash

          ENV["PGUSER"]         = pg_config[:username] if pg_config[:username]
          ENV["PGHOST"]         = pg_config[:host] if pg_config[:host]
          ENV["PGPORT"]         = pg_config[:port].to_s if pg_config[:port]
          ENV["PGPASSWORD"]     = pg_config[:password].to_s if pg_config[:password] && options[:include_password]
          ENV["PGSSLMODE"]      = pg_config[:sslmode].to_s if pg_config[:sslmode]
          ENV["PGSSLCERT"]      = pg_config[:sslcert].to_s if pg_config[:sslcert]
          ENV["PGSSLKEY"]       = pg_config[:sslkey].to_s if pg_config[:sslkey]
          ENV["PGSSLROOTCERT"]  = pg_config[:sslrootcert].to_s if pg_config[:sslrootcert]
          if pg_config[:variables]
            ENV["PGOPTIONS"] = pg_config[:variables].filter_map do |name, value|
              "-c #{name}=#{value.to_s.gsub(/[ \\]/, '\\\\\0')}" unless value == ":default" || value == :default
            end.join(" ")
          end
          find_cmd_and_exec(ActiveRecord.database_cli[:postgresql], config.database)
        end
      end

      ##
      # :singleton-method:
      # PostgreSQL allows the creation of "unlogged" tables, which do not record
      # data in the PostgreSQL Write-Ahead Log. This can make the tables faster,
      # but significantly increases the risk of data loss if the database
      # crashes. As a result, this should not be used in production
      # environments. If you would like all created tables to be unlogged in
      # the test environment you can add the following to your test.rb file:
      #
      #   ActiveSupport.on_load(:active_record_postgresqladapter) do
      #     self.create_unlogged_tables = true
      #   end
      class_attribute :create_unlogged_tables, default: false

      ##
      # :singleton-method:
      # PostgreSQL supports multiple types for DateTimes. By default, if you use +datetime+
      # in migrations, \Rails will translate this to a PostgreSQL "timestamp without time zone".
      # Change this in an initializer to use another NATIVE_DATABASE_TYPES. For example, to
      # store DateTimes as "timestamp with time zone":
      #
      #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :timestamptz
      #
      # Or if you are adding a custom type:
      #
      #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::NATIVE_DATABASE_TYPES[:my_custom_type] = { name: "my_custom_type_name" }
      #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.datetime_type = :my_custom_type
      #
      # If you're using +:ruby+ as your +config.active_record.schema_format+ and you change this
      # setting, you should immediately run <tt>bin/rails db:migrate</tt> to update the types in your schema.rb.
      class_attribute :datetime_type, default: :timestamp

      ##
      # :singleton-method:
      # Toggles automatic decoding of date columns.
      #
      #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.select_value("select '2024-01-01'::date").class #=> String
      #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.decode_dates = true
      #   ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.select_value("select '2024-01-01'::date").class #=> Date
      class_attribute :decode_dates, default: false

      NATIVE_DATABASE_TYPES = {
        primary_key: "bigserial primary key",
        string:      { name: "character varying" },
        text:        { name: "text" },
        integer:     { name: "integer", limit: 4 },
        bigint:      { name: "bigint" },
        float:       { name: "float" },
        decimal:     { name: "decimal" },
        datetime:    {}, # set dynamically based on datetime_type
        timestamp:   { name: "timestamp" },
        timestamptz: { name: "timestamptz" },
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
        jsonb:       { name: "jsonb" },
        ltree:       { name: "ltree" },
        citext:      { name: "citext" },
        point:       { name: "point" },
        line:        { name: "line" },
        lseg:        { name: "lseg" },
        box:         { name: "box" },
        path:        { name: "path" },
        polygon:     { name: "polygon" },
        circle:      { name: "circle" },
        bit:         { name: "bit" },
        bit_varying: { name: "bit varying" },
        money:       { name: "money" },
        interval:    { name: "interval" },
        oid:         { name: "oid" },
        enum:        {} # special type https://www.postgresql.org/docs/current/datatype-enum.html
      }

      OID = PostgreSQL::OID # :nodoc:

      include PostgreSQL::Quoting
      include PostgreSQL::ReferentialIntegrity
      include PostgreSQL::SchemaStatements
      include PostgreSQL::DatabaseStatements

      def supports_bulk_alter?
        true
      end

      def supports_index_sort_order?
        true
      end

      def supports_partitioned_indexes?
        database_version >= 11_00_00 # >= 11.0
      end

      def supports_partial_index?
        true
      end

      def supports_index_include?
        database_version >= 11_00_00 # >= 11.0
      end

      def supports_expression_index?
        true
      end

      def supports_transaction_isolation?
        true
      end

      def supports_foreign_keys?
        true
      end

      def supports_check_constraints?
        true
      end

      def supports_exclusion_constraints?
        true
      end

      def supports_unique_constraints?
        true
      end

      def supports_validate_constraints?
        true
      end

      def supports_deferrable_constraints?
        true
      end

      def supports_views?
        true
      end

      def supports_datetime_with_precision?
        true
      end

      def supports_json?
        true
      end

      def supports_comments?
        true
      end

      def supports_savepoints?
        true
      end

      def supports_restart_db_transaction?
        database_version >= 12_00_00 # >= 12.0
      end

      def supports_insert_returning?
        true
      end

      def supports_insert_on_conflict?
        database_version >= 9_05_00 # >= 9.5
      end
      alias supports_insert_on_duplicate_skip? supports_insert_on_conflict?
      alias supports_insert_on_duplicate_update? supports_insert_on_conflict?
      alias supports_insert_conflict_target? supports_insert_on_conflict?

      def supports_virtual_columns?
        database_version >= 12_00_00 # >= 12.0
      end

      def supports_identity_columns? # :nodoc:
        database_version >= 10_00_00 # >= 10.0
      end

      def supports_nulls_not_distinct?
        database_version >= 15_00_00 # >= 15.0
      end

      def supports_native_partitioning? # :nodoc:
        database_version >= 10_00_00 # >= 10.0
      end

      def index_algorithms
        { concurrently: "CONCURRENTLY" }
      end

      class StatementPool < ConnectionAdapters::StatementPool # :nodoc:
        def initialize(connection, max)
          super(max)
          @connection = connection
          @counter = 0
        end

        def next_key
          "a#{@counter += 1}"
        end

        private
          def dealloc(key)
            # This is ugly, but safe: the statement pool is only
            # accessed while holding the connection's lock. (And we
            # don't need the complication of with_raw_connection because
            # a reconnect would invalidate the entire statement pool.)
            if conn = @connection.instance_variable_get(:@raw_connection)
              conn.query "DEALLOCATE #{key}" if conn.status == PG::CONNECTION_OK
            end
          rescue PG::Error
          end
      end

      # Initializes and connects a PostgreSQL adapter.
      def initialize(...)
        super

        conn_params = @config.compact

        # Map ActiveRecords param names to PGs.
        conn_params[:user] = conn_params.delete(:username) if conn_params[:username]
        conn_params[:dbname] = conn_params.delete(:database) if conn_params[:database]

        # Forward only valid config params to PG::Connection.connect.
        valid_conn_param_keys = PG::Connection.conndefaults_hash.keys + [:requiressl]
        conn_params.slice!(*valid_conn_param_keys)

        @connection_parameters = conn_params

        @max_identifier_length = nil
        @type_map = nil
        @raw_connection = nil
        @notice_receiver_sql_warnings = []

        @use_insert_returning = @config.key?(:insert_returning) ? self.class.type_cast_config_to_boolean(@config[:insert_returning]) : true
      end

      def connected?
        !(@raw_connection.nil? || @raw_connection.finished?)
      end

      # Is this connection alive and ready for queries?
      def active?
        @lock.synchronize do
          return false unless @raw_connection
          @raw_connection.query ";"
          verified!
        end
        true
      rescue PG::Error
        false
      end

      def reload_type_map # :nodoc:
        @lock.synchronize do
          if @type_map
            type_map.clear
          else
            @type_map = Type::HashLookupTypeMap.new
          end

          initialize_type_map
        end
      end

      def reset!
        @lock.synchronize do
          return connect! unless @raw_connection

          unless @raw_connection.transaction_status == ::PG::PQTRANS_IDLE
            @raw_connection.query "ROLLBACK"
          end
          @raw_connection.query "DISCARD ALL"

          super
        end
      end

      # Disconnects from the database if already connected. Otherwise, this
      # method does nothing.
      def disconnect!
        @lock.synchronize do
          super
          @raw_connection&.close rescue nil
          @raw_connection = nil
        end
      end

      def discard! # :nodoc:
        super
        @raw_connection&.socket_io&.reopen(IO::NULL) rescue nil
        @raw_connection = nil
      end

      def native_database_types # :nodoc:
        self.class.native_database_types
      end

      def self.native_database_types # :nodoc:
        @native_database_types ||= begin
          types = NATIVE_DATABASE_TYPES.dup
          types[:datetime] = types[datetime_type]
          types
        end
      end

      def set_standard_conforming_strings
        internal_execute("SET standard_conforming_strings = on", "SCHEMA")
      end

      def supports_ddl_transactions?
        true
      end

      def supports_advisory_locks?
        true
      end

      def supports_explain?
        true
      end

      def supports_extensions?
        true
      end

      def supports_materialized_views?
        true
      end

      def supports_foreign_tables?
        true
      end

      def supports_pgcrypto_uuid?
        database_version >= 9_04_00 # >= 9.4
      end

      def supports_optimizer_hints?
        unless defined?(@has_pg_hint_plan)
          @has_pg_hint_plan = extension_available?("pg_hint_plan")
        end
        @has_pg_hint_plan
      end

      def supports_common_table_expressions?
        true
      end

      def supports_lazy_transactions?
        true
      end

      def get_advisory_lock(lock_id) # :nodoc:
        unless lock_id.is_a?(Integer) && lock_id.bit_length <= 63
          raise(ArgumentError, "PostgreSQL requires advisory lock ids to be a signed 64 bit integer")
        end
        query_value("SELECT pg_try_advisory_lock(#{lock_id})")
      end

      def release_advisory_lock(lock_id) # :nodoc:
        unless lock_id.is_a?(Integer) && lock_id.bit_length <= 63
          raise(ArgumentError, "PostgreSQL requires advisory lock ids to be a signed 64 bit integer")
        end
        query_value("SELECT pg_advisory_unlock(#{lock_id})")
      end

      def enable_extension(name, **)
        schema, name = name.to_s.split(".").values_at(-2, -1)
        sql = +"CREATE EXTENSION IF NOT EXISTS \"#{name}\""
        sql << " SCHEMA #{schema}" if schema

        internal_exec_query(sql).tap { reload_type_map }
      end

      # Removes an extension from the database.
      #
      # [<tt>:force</tt>]
      #   Set to +:cascade+ to drop dependent objects as well.
      #   Defaults to false.
      def disable_extension(name, force: false)
        _schema, name = name.to_s.split(".").values_at(-2, -1)
        internal_exec_query("DROP EXTENSION IF EXISTS \"#{name}\"#{' CASCADE' if force == :cascade}").tap {
          reload_type_map
        }
      end

      def extension_available?(name)
        query_value("SELECT true FROM pg_available_extensions WHERE name = #{quote(name)}", "SCHEMA")
      end

      def extension_enabled?(name)
        query_value("SELECT installed_version IS NOT NULL FROM pg_available_extensions WHERE name = #{quote(name)}", "SCHEMA")
      end

      def extensions
        query = <<~SQL
          SELECT
            pg_extension.extname,
            n.nspname AS schema
          FROM pg_extension
          JOIN pg_namespace n ON pg_extension.extnamespace = n.oid
        SQL

        internal_exec_query(query, "SCHEMA", allow_retry: true, materialize_transactions: false).cast_values.map do |row|
          name, schema = row[0], row[1]
          schema = nil if schema == current_schema
          [schema, name].compact.join(".")
        end
      end

      # Returns a list of defined enum types, and their values.
      def enum_types
        query = <<~SQL
          SELECT
            type.typname AS name,
            type.OID AS oid,
            n.nspname AS schema,
            array_agg(enum.enumlabel ORDER BY enum.enumsortorder) AS value
          FROM pg_enum AS enum
          JOIN pg_type AS type ON (type.oid = enum.enumtypid)
          JOIN pg_namespace n ON type.typnamespace = n.oid
          WHERE n.nspname = ANY (current_schemas(false))
          GROUP BY type.OID, n.nspname, type.typname;
        SQL

        internal_exec_query(query, "SCHEMA", allow_retry: true, materialize_transactions: false).cast_values.each_with_object({}) do |row, memo|
          name, schema = row[0], row[2]
          schema = nil if schema == current_schema
          full_name = [schema, name].compact.join(".")
          memo[full_name] = row.last
        end.to_a
      end

      # Given a name and an array of values, creates an enum type.
      def create_enum(name, values, **options)
        sql_values = values.map { |s| quote(s) }.join(", ")
        scope = quoted_scope(name)
        query = <<~SQL
          DO $$
          BEGIN
              IF NOT EXISTS (
                SELECT 1
                FROM pg_type t
                JOIN pg_namespace n ON t.typnamespace = n.oid
                WHERE t.typname = #{scope[:name]}
                  AND n.nspname = #{scope[:schema]}
              ) THEN
                  CREATE TYPE #{quote_table_name(name)} AS ENUM (#{sql_values});
              END IF;
          END
          $$;
        SQL
        internal_exec_query(query).tap { reload_type_map }
      end

      # Drops an enum type.
      #
      # If the <tt>if_exists: true</tt> option is provided, the enum is dropped
      # only if it exists. Otherwise, if the enum doesn't exist, an error is
      # raised.
      #
      # The +values+ parameter will be ignored if present. It can be helpful
      # to provide this in a migration's +change+ method so it can be reverted.
      # In that case, +values+ will be used by #create_enum.
      def drop_enum(name, values = nil, **options)
        query = <<~SQL
          DROP TYPE#{' IF EXISTS' if options[:if_exists]} #{quote_table_name(name)};
        SQL
        internal_exec_query(query).tap { reload_type_map }
      end

      # Rename an existing enum type to something else.
      def rename_enum(name, new_name = nil, **options)
        new_name ||= options.fetch(:to) do
          raise ArgumentError, "rename_enum requires two from/to name positional arguments."
        end

        exec_query("ALTER TYPE #{quote_table_name(name)} RENAME TO #{quote_table_name(new_name)}").tap { reload_type_map }
      end

      # Add enum value to an existing enum type.
      def add_enum_value(type_name, value, **options)
        before, after = options.values_at(:before, :after)
        sql = +"ALTER TYPE #{quote_table_name(type_name)} ADD VALUE"
        sql << " IF NOT EXISTS" if options[:if_not_exists]
        sql << " #{quote(value)}"

        if before && after
          raise ArgumentError, "Cannot have both :before and :after at the same time"
        elsif before
          sql << " BEFORE #{quote(before)}"
        elsif after
          sql << " AFTER #{quote(after)}"
        end

        execute(sql).tap { reload_type_map }
      end

      # Rename enum value on an existing enum type.
      def rename_enum_value(type_name, **options)
        unless database_version >= 10_00_00 # >= 10.0
          raise ArgumentError, "Renaming enum values is only supported in PostgreSQL 10 or later"
        end

        from = options.fetch(:from) { raise ArgumentError, ":from is required" }
        to = options.fetch(:to) { raise ArgumentError, ":to is required" }

        execute("ALTER TYPE #{quote_table_name(type_name)} RENAME VALUE #{quote(from)} TO #{quote(to)}").tap {
          reload_type_map
        }
      end

      # Returns the configured supported identifier length supported by PostgreSQL
      def max_identifier_length
        @max_identifier_length ||= query_value("SHOW max_identifier_length", "SCHEMA").to_i
      end

      # Set the authorized user for this session
      def session_auth=(user)
        clear_cache!
        internal_execute("SET SESSION AUTHORIZATION #{user}", nil, materialize_transactions: true)
      end

      def use_insert_returning?
        @use_insert_returning
      end

      # Returns the version of the connected PostgreSQL server.
      def get_database_version # :nodoc:
        with_raw_connection do |conn|
          version = conn.server_version
          if version == 0
            raise ActiveRecord::ConnectionFailed, "Could not determine PostgreSQL version"
          end
          version
        end
      end
      alias :postgresql_version :database_version

      def default_index_type?(index) # :nodoc:
        index.using == :btree || super
      end

      def build_insert_sql(insert) # :nodoc:
        sql = +"INSERT #{insert.into} #{insert.values_list}"

        if insert.skip_duplicates?
          sql << " ON CONFLICT #{insert.conflict_target} DO NOTHING"
        elsif insert.update_duplicates?
          sql << " ON CONFLICT #{insert.conflict_target} DO UPDATE SET "
          if insert.raw_update_sql?
            sql << insert.raw_update_sql
          else
            sql << insert.touch_model_timestamps_unless { |column| "#{insert.model.quoted_table_name}.#{column} IS NOT DISTINCT FROM excluded.#{column}" }
            sql << insert.updatable_columns.map { |column| "#{column}=excluded.#{column}" }.join(",")
          end
        end

        sql << " RETURNING #{insert.returning}" if insert.returning
        sql
      end

      def check_version # :nodoc:
        if database_version < 9_03_00 # < 9.3
          raise "Your version of PostgreSQL (#{database_version}) is too old. Active Record supports PostgreSQL >= 9.3."
        end
      end

      class << self
        def initialize_type_map(m) # :nodoc:
          m.register_type "int2", Type::Integer.new(limit: 2)
          m.register_type "int4", Type::Integer.new(limit: 4)
          m.register_type "int8", Type::Integer.new(limit: 8)
          m.register_type "oid", OID::Oid.new
          m.register_type "float4", Type::Float.new(limit: 24)
          m.register_type "float8", Type::Float.new
          m.register_type "text", Type::Text.new
          register_class_with_limit m, "varchar", Type::String
          m.alias_type "char", "varchar"
          m.alias_type "name", "varchar"
          m.alias_type "bpchar", "varchar"
          m.register_type "bool", Type::Boolean.new
          register_class_with_limit m, "bit", OID::Bit
          register_class_with_limit m, "varbit", OID::BitVarying
          m.register_type "date", OID::Date.new

          m.register_type "money", OID::Money.new
          m.register_type "bytea", OID::Bytea.new
          m.register_type "point", OID::Point.new
          m.register_type "hstore", OID::Hstore.new
          m.register_type "json", Type::Json.new
          m.register_type "jsonb", OID::Jsonb.new
          m.register_type "cidr", OID::Cidr.new
          m.register_type "inet", OID::Inet.new
          m.register_type "uuid", OID::Uuid.new
          m.register_type "xml", OID::Xml.new
          m.register_type "tsvector", OID::SpecializedString.new(:tsvector)
          m.register_type "macaddr", OID::Macaddr.new
          m.register_type "citext", OID::SpecializedString.new(:citext)
          m.register_type "ltree", OID::SpecializedString.new(:ltree)
          m.register_type "line", OID::SpecializedString.new(:line)
          m.register_type "lseg", OID::SpecializedString.new(:lseg)
          m.register_type "box", OID::SpecializedString.new(:box)
          m.register_type "path", OID::SpecializedString.new(:path)
          m.register_type "polygon", OID::SpecializedString.new(:polygon)
          m.register_type "circle", OID::SpecializedString.new(:circle)

          m.register_type "numeric" do |_, fmod, sql_type|
            precision = extract_precision(sql_type)
            scale = extract_scale(sql_type)

            # The type for the numeric depends on the width of the field,
            # so we'll do something special here.
            #
            # When dealing with decimal columns:
            #
            # places after decimal  = fmod - 4 & 0xffff
            # places before decimal = (fmod - 4) >> 16 & 0xffff
            if fmod && (fmod - 4 & 0xffff).zero?
              # FIXME: Remove this class, and the second argument to
              # lookups on PG
              Type::DecimalWithoutScale.new(precision: precision)
            else
              OID::Decimal.new(precision: precision, scale: scale)
            end
          end

          m.register_type "interval" do |*args, sql_type|
            precision = extract_precision(sql_type)
            OID::Interval.new(precision: precision)
          end
        end
      end

      private
        attr_reader :type_map

        def initialize_type_map(m = type_map)
          self.class.initialize_type_map(m)

          self.class.register_class_with_precision m, "time", Type::Time, timezone: @default_timezone
          self.class.register_class_with_precision m, "timestamp", OID::Timestamp, timezone: @default_timezone
          self.class.register_class_with_precision m, "timestamptz", OID::TimestampWithTimeZone

          load_additional_types
        end

        # Extracts the value from a PostgreSQL column default definition.
        def extract_value_from_default(default)
          case default
            # Quoted types
          when /\A[(B]?'(.*)'.*::"?([\w. ]+)"?(?:\[\])?\z/m
            # The default 'now'::date is CURRENT_DATE
            if $1 == "now" && $2 == "date"
              nil
            else
              $1.gsub("''", "'")
            end
            # Boolean types
          when "true", "false"
            default
            # Numeric types
          when /\A\(?(-?\d+(\.\d*)?)\)?(::bigint)?\z/
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

        def extract_default_function(default_value, default)
          default if has_default_function?(default_value, default)
        end

        def has_default_function?(default_value, default)
          !default_value && %r{\w+\(.*\)|\(.*\)::\w+|CURRENT_DATE|CURRENT_TIMESTAMP}.match?(default)
        end

        # See https://www.postgresql.org/docs/current/static/errcodes-appendix.html
        VALUE_LIMIT_VIOLATION = "22001"
        NUMERIC_VALUE_OUT_OF_RANGE = "22003"
        NOT_NULL_VIOLATION    = "23502"
        FOREIGN_KEY_VIOLATION = "23503"
        UNIQUE_VIOLATION      = "23505"
        SERIALIZATION_FAILURE = "40001"
        DEADLOCK_DETECTED     = "40P01"
        DUPLICATE_DATABASE    = "42P04"
        LOCK_NOT_AVAILABLE    = "55P03"
        QUERY_CANCELED        = "57014"

        def translate_exception(exception, message:, sql:, binds:)
          return exception unless exception.respond_to?(:result)

          case exception.result.try(:error_field, PG::PG_DIAG_SQLSTATE)
          when nil
            if exception.message.match?(/connection is closed/i) || exception.message.match?(/no connection to the server/i)
              ConnectionNotEstablished.new(exception, connection_pool: @pool)
            elsif exception.is_a?(PG::ConnectionBad)
              # libpq message style always ends with a newline; the pg gem's internal
              # errors do not. We separate these cases because a pg-internal
              # ConnectionBad means it failed before it managed to send the query,
              # whereas a libpq failure could have occurred at any time (meaning the
              # server may have already executed part or all of the query).
              if exception.message.end_with?("\n")
                ConnectionFailed.new(exception, connection_pool: @pool)
              else
                ConnectionNotEstablished.new(exception, connection_pool: @pool)
              end
            else
              super
            end
          when UNIQUE_VIOLATION
            RecordNotUnique.new(message, sql: sql, binds: binds, connection_pool: @pool)
          when FOREIGN_KEY_VIOLATION
            InvalidForeignKey.new(message, sql: sql, binds: binds, connection_pool: @pool)
          when VALUE_LIMIT_VIOLATION
            ValueTooLong.new(message, sql: sql, binds: binds, connection_pool: @pool)
          when NUMERIC_VALUE_OUT_OF_RANGE
            RangeError.new(message, sql: sql, binds: binds, connection_pool: @pool)
          when NOT_NULL_VIOLATION
            NotNullViolation.new(message, sql: sql, binds: binds, connection_pool: @pool)
          when SERIALIZATION_FAILURE
            SerializationFailure.new(message, sql: sql, binds: binds, connection_pool: @pool)
          when DEADLOCK_DETECTED
            Deadlocked.new(message, sql: sql, binds: binds, connection_pool: @pool)
          when DUPLICATE_DATABASE
            DatabaseAlreadyExists.new(message, sql: sql, binds: binds, connection_pool: @pool)
          when LOCK_NOT_AVAILABLE
            LockWaitTimeout.new(message, sql: sql, binds: binds, connection_pool: @pool)
          when QUERY_CANCELED
            QueryCanceled.new(message, sql: sql, binds: binds, connection_pool: @pool)
          else
            super
          end
        end

        def retryable_query_error?(exception)
          # We cannot retry anything if we're inside a broken transaction; we need to at
          # least raise until the innermost savepoint is rolled back
          @raw_connection&.transaction_status != ::PG::PQTRANS_INERROR &&
            super
        end

        def get_oid_type(oid, fmod, column_name, sql_type = "")
          if !type_map.key?(oid)
            load_additional_types([oid])
          end

          type_map.fetch(oid, fmod, sql_type) {
            warn "unknown OID #{oid}: failed to recognize type of '#{column_name}'. It will be treated as String."
            Type.default_value.tap do |cast_type|
              type_map.register_type(oid, cast_type)
            end
          }
        end

        def load_additional_types(oids = nil)
          initializer = OID::TypeMapInitializer.new(type_map)
          load_types_queries(initializer, oids) do |query|
            records = internal_execute(query, "SCHEMA", [], allow_retry: true, materialize_transactions: false)
            initializer.run(records)
          end
        end

        def load_types_queries(initializer, oids)
          query = <<~SQL
            SELECT t.oid, t.typname, t.typelem, t.typdelim, t.typinput, r.rngsubtype, t.typtype, t.typbasetype
            FROM pg_type as t
            LEFT JOIN pg_range as r ON oid = rngtypid
          SQL
          if oids
            yield query + "WHERE t.oid IN (%s)" % oids.join(", ")
          else
            yield query + initializer.query_conditions_for_known_type_names
            yield query + initializer.query_conditions_for_known_type_types
            yield query + initializer.query_conditions_for_array_types
          end
        end

        FEATURE_NOT_SUPPORTED = "0A000" # :nodoc:

        # Annoyingly, the code for prepared statements whose return value may
        # have changed is FEATURE_NOT_SUPPORTED.
        #
        # This covers various different error types so we need to do additional
        # work to classify the exception definitively as a
        # ActiveRecord::PreparedStatementCacheExpired
        #
        # Check here for more details:
        # https://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/backend/utils/cache/plancache.c#l573
        def is_cached_plan_failure?(pgerror)
          pgerror.result.result_error_field(PG::PG_DIAG_SQLSTATE) == FEATURE_NOT_SUPPORTED &&
            pgerror.result.result_error_field(PG::PG_DIAG_SOURCE_FUNCTION) == "RevalidateCachedQuery"
        rescue
          false
        end

        def in_transaction?
          open_transactions > 0
        end

        # Returns the statement identifier for the client side cache
        # of statements
        def sql_key(sql)
          "#{schema_search_path}-#{sql}"
        end

        # Prepare the statement if it hasn't been prepared, return
        # the statement key.
        def prepare_statement(sql, binds, conn)
          sql_key = sql_key(sql)
          unless @statements.key? sql_key
            nextkey = @statements.next_key
            begin
              conn.prepare nextkey, sql
            rescue => e
              raise translate_exception_class(e, sql, binds)
            end
            # Clear the queue
            conn.get_last_result
            @statements[sql_key] = nextkey
          end
          @statements[sql_key]
        end

        # Connects to a PostgreSQL server and sets up the adapter depending on the
        # connected server's characteristics.
        def connect
          @raw_connection = self.class.new_client(@connection_parameters)
        rescue ConnectionNotEstablished => ex
          raise ex.set_pool(@pool)
        end

        def reconnect
          begin
            @raw_connection&.reset
          rescue PG::ConnectionBad
            @raw_connection = nil
          end

          connect unless @raw_connection
        end

        # Configures the encoding, verbosity, schema search path, and time zone of the connection.
        # This is called by #connect and should not be called manually.
        def configure_connection
          super

          if @config[:encoding]
            @raw_connection.set_client_encoding(@config[:encoding])
          end
          self.client_min_messages = @config[:min_messages] || "warning"
          self.schema_search_path = @config[:schema_search_path] || @config[:schema_order]

          unless ActiveRecord.db_warnings_action.nil?
            @raw_connection.set_notice_receiver do |result|
              message = result.error_field(PG::Result::PG_DIAG_MESSAGE_PRIMARY)
              code = result.error_field(PG::Result::PG_DIAG_SQLSTATE)
              level = result.error_field(PG::Result::PG_DIAG_SEVERITY)
              @notice_receiver_sql_warnings << SQLWarning.new(message, code, level, nil, @pool)
            end
          end

          # Use standard-conforming strings so we don't have to do the E'...' dance.
          set_standard_conforming_strings

          variables = @config.fetch(:variables, {}).stringify_keys

          # Set interval output format to ISO 8601 for ease of parsing by ActiveSupport::Duration.parse
          internal_execute("SET intervalstyle = iso_8601", "SCHEMA")

          # SET statements from :variables config hash
          # https://www.postgresql.org/docs/current/static/sql-set.html
          variables.map do |k, v|
            if v == ":default" || v == :default
              # Sets the value to the global or compile default
              internal_execute("SET SESSION #{k} TO DEFAULT", "SCHEMA")
            elsif !v.nil?
              internal_execute("SET SESSION #{k} TO #{quote(v)}", "SCHEMA")
            end
          end

          add_pg_encoders
          add_pg_decoders

          reload_type_map
        end

        def reconfigure_connection_timezone
          variables = @config.fetch(:variables, {}).stringify_keys

          # If it's been directly configured as a connection variable, we don't
          # need to do anything here; it will be set up by configure_connection
          # and then never changed.
          return if variables["timezone"]

          # If using Active Record's time zone support configure the connection
          # to return TIMESTAMP WITH ZONE types in UTC.
          if default_timezone == :utc
            raw_execute("SET SESSION timezone TO 'UTC'", "SCHEMA")
          else
            raw_execute("SET SESSION timezone TO DEFAULT", "SCHEMA")
          end
        end

        # Returns the list of a table's column names, data types, and default values.
        #
        # The underlying query is roughly:
        #  SELECT column.name, column.type, default.value, column.comment
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
          query(<<~SQL, "SCHEMA")
              SELECT a.attname, format_type(a.atttypid, a.atttypmod),
                     pg_get_expr(d.adbin, d.adrelid), a.attnotnull, a.atttypid, a.atttypmod,
                     c.collname, col_description(a.attrelid, a.attnum) AS comment,
                     #{supports_identity_columns? ? 'attidentity' : quote('')} AS identity,
                     #{supports_virtual_columns? ? 'attgenerated' : quote('')} as attgenerated
                FROM pg_attribute a
                LEFT JOIN pg_attrdef d ON a.attrelid = d.adrelid AND a.attnum = d.adnum
                LEFT JOIN pg_type t ON a.atttypid = t.oid
                LEFT JOIN pg_collation c ON a.attcollation = c.oid AND a.attcollation <> t.typcollation
               WHERE a.attrelid = #{quote(quote_table_name(table_name))}::regclass
                 AND a.attnum > 0 AND NOT a.attisdropped
               ORDER BY a.attnum
          SQL
        end

        def arel_visitor
          Arel::Visitors::PostgreSQL.new(self)
        end

        def build_statement_pool
          StatementPool.new(self, self.class.type_cast_config_to_integer(@config[:statement_limit]))
        end

        def can_perform_case_insensitive_comparison_for?(column)
          # NOTE: citext is an exception. It is possible to perform a
          #       case-insensitive comparison using `LOWER()`, but it is
          #       unnecessary, as `citext` is case-insensitive by definition.
          @case_insensitive_cache ||= { "citext" => false }
          @case_insensitive_cache.fetch(column.sql_type) do
            @case_insensitive_cache[column.sql_type] = begin
              sql = <<~SQL
                SELECT exists(
                  SELECT * FROM pg_proc
                  WHERE proname = 'lower'
                    AND proargtypes = ARRAY[#{quote column.sql_type}::regtype]::oidvector
                ) OR exists(
                  SELECT * FROM pg_proc
                  INNER JOIN pg_cast
                    ON ARRAY[casttarget]::oidvector = proargtypes
                  WHERE proname = 'lower'
                    AND castsource = #{quote column.sql_type}::regtype
                )
              SQL
              result = internal_execute(sql, "SCHEMA", [], allow_retry: true, materialize_transactions: false)
              result.getvalue(0, 0)
            end
          end
        end

        def add_pg_encoders
          map = PG::TypeMapByClass.new
          map[Integer] = PG::TextEncoder::Integer.new
          map[TrueClass] = PG::TextEncoder::Boolean.new
          map[FalseClass] = PG::TextEncoder::Boolean.new
          @raw_connection.type_map_for_queries = map
        end

        def update_typemap_for_default_timezone
          if @raw_connection && @mapped_default_timezone != default_timezone && @timestamp_decoder
            decoder_class = default_timezone == :utc ?
              PG::TextDecoder::TimestampUtc :
              PG::TextDecoder::TimestampWithoutTimeZone

            @timestamp_decoder = decoder_class.new(**@timestamp_decoder.to_h)
            @raw_connection.type_map_for_results.add_coder(@timestamp_decoder)

            @mapped_default_timezone = default_timezone

            # if default timezone has changed, we need to reconfigure the connection
            # (specifically, the session time zone)
            reconfigure_connection_timezone

            true
          end
        end

        def add_pg_decoders
          @mapped_default_timezone = nil
          @timestamp_decoder = nil

          coders_by_name = {
            "int2" => PG::TextDecoder::Integer,
            "int4" => PG::TextDecoder::Integer,
            "int8" => PG::TextDecoder::Integer,
            "oid" => PG::TextDecoder::Integer,
            "float4" => PG::TextDecoder::Float,
            "float8" => PG::TextDecoder::Float,
            "numeric" => PG::TextDecoder::Numeric,
            "bool" => PG::TextDecoder::Boolean,
            "timestamp" => PG::TextDecoder::TimestampUtc,
            "timestamptz" => PG::TextDecoder::TimestampWithTimeZone,
          }
          coders_by_name["date"] = PG::TextDecoder::Date if decode_dates

          known_coder_types = coders_by_name.keys.map { |n| quote(n) }
          query = <<~SQL % known_coder_types.join(", ")
            SELECT t.oid, t.typname
            FROM pg_type as t
            WHERE t.typname IN (%s)
          SQL
          result = internal_execute(query, "SCHEMA", [], allow_retry: true, materialize_transactions: false)
          coders = result.filter_map { |row| construct_coder(row, coders_by_name[row["typname"]]) }

          map = PG::TypeMapByOid.new
          coders.each { |coder| map.add_coder(coder) }
          @raw_connection.type_map_for_results = map

          @type_map_for_results = PG::TypeMapByOid.new
          @type_map_for_results.default_type_map = map
          @type_map_for_results.add_coder(PG::TextDecoder::Bytea.new(oid: 17, name: "bytea"))
          @type_map_for_results.add_coder(MoneyDecoder.new(oid: 790, name: "money"))

          # extract timestamp decoder for use in update_typemap_for_default_timezone
          @timestamp_decoder = coders.find { |coder| coder.name == "timestamp" }
          update_typemap_for_default_timezone
        end

        def construct_coder(row, coder_class)
          return unless coder_class
          coder_class.new(oid: row["oid"].to_i, name: row["typname"])
        end

        class MoneyDecoder < PG::SimpleDecoder # :nodoc:
          TYPE = OID::Money.new

          def decode(value, tuple = nil, field = nil)
            TYPE.deserialize(value)
          end
        end

        ActiveRecord::Type.add_modifier({ array: true }, OID::Array, adapter: :postgresql)
        ActiveRecord::Type.add_modifier({ range: true }, OID::Range, adapter: :postgresql)
        ActiveRecord::Type.register(:bit, OID::Bit, adapter: :postgresql)
        ActiveRecord::Type.register(:bit_varying, OID::BitVarying, adapter: :postgresql)
        ActiveRecord::Type.register(:binary, OID::Bytea, adapter: :postgresql)
        ActiveRecord::Type.register(:cidr, OID::Cidr, adapter: :postgresql)
        ActiveRecord::Type.register(:date, OID::Date, adapter: :postgresql)
        ActiveRecord::Type.register(:datetime, OID::DateTime, adapter: :postgresql)
        ActiveRecord::Type.register(:decimal, OID::Decimal, adapter: :postgresql)
        ActiveRecord::Type.register(:enum, OID::Enum, adapter: :postgresql)
        ActiveRecord::Type.register(:hstore, OID::Hstore, adapter: :postgresql)
        ActiveRecord::Type.register(:inet, OID::Inet, adapter: :postgresql)
        ActiveRecord::Type.register(:interval, OID::Interval, adapter: :postgresql)
        ActiveRecord::Type.register(:jsonb, OID::Jsonb, adapter: :postgresql)
        ActiveRecord::Type.register(:money, OID::Money, adapter: :postgresql)
        ActiveRecord::Type.register(:point, OID::Point, adapter: :postgresql)
        ActiveRecord::Type.register(:legacy_point, OID::LegacyPoint, adapter: :postgresql)
        ActiveRecord::Type.register(:uuid, OID::Uuid, adapter: :postgresql)
        ActiveRecord::Type.register(:vector, OID::Vector, adapter: :postgresql)
        ActiveRecord::Type.register(:xml, OID::Xml, adapter: :postgresql)
    end
    ActiveSupport.run_load_hooks(:active_record_postgresqladapter, PostgreSQLAdapter)
  end
end
