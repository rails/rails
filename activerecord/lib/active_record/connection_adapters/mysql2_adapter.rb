gem "mysql2", ">= 0.3.18", "< 0.5"
require "mysql2"
raise "mysql2 0.4.3 is not supported. Please upgrade to 0.4.4+" if Mysql2::VERSION == "0.4.3"

require "active_record/connection_adapters/abstract_adapter"
require "active_record/connection_adapters/statement_pool"
require "active_record/connection_adapters/mysql/column"
require "active_record/connection_adapters/mysql/database_statements"
require "active_record/connection_adapters/mysql/explain_pretty_printer"
require "active_record/connection_adapters/mysql/quoting"
require "active_record/connection_adapters/mysql/schema_creation"
require "active_record/connection_adapters/mysql/schema_definitions"
require "active_record/connection_adapters/mysql/schema_dumper"
require "active_record/connection_adapters/mysql/schema_statements"
require "active_record/connection_adapters/mysql/type_metadata"

require "active_support/core_ext/string/strip"

module ActiveRecord
  module ConnectionHandling # :nodoc:
    # Establishes a connection to the database that's used by all Active Record objects.
    def mysql2_connection(config)
      config = config.symbolize_keys

      config[:username] = "root" if config[:username].nil?
      config[:flags] ||= 0

      if Mysql2::Client.const_defined? :FOUND_ROWS
        if config[:flags].kind_of? Array
          config[:flags].push "FOUND_ROWS".freeze
        else
          config[:flags] |= Mysql2::Client::FOUND_ROWS
        end
      end

      client = Mysql2::Client.new(config)
      ConnectionAdapters::Mysql2Adapter.new(client, logger, nil, config)
    rescue Mysql2::Error => error
      if error.message.include?("Unknown database")
        raise ActiveRecord::NoDatabaseError
      else
        raise
      end
    end
  end

  module ConnectionAdapters
    class Mysql2Adapter < AbstractAdapter
      ADAPTER_NAME = "Mysql2".freeze

      include MySQL::Quoting
      include MySQL::ColumnDumper
      include MySQL::DatabaseStatements
      include MySQL::SchemaStatements

      def update_table_definition(table_name, base) # :nodoc:
        MySQL::Table.new(table_name, base)
      end

      def schema_creation # :nodoc:
        MySQL::SchemaCreation.new(self)
      end

      def arel_visitor # :nodoc:
        Arel::Visitors::MySQL.new(self)
      end

      ##
      # :singleton-method:
      # By default, the Mysql2Adapter will consider all columns of type <tt>tinyint(1)</tt>
      # as boolean. If you wish to disable this emulation you can add the following line
      # to your application.rb file:
      #
      #   ActiveRecord::ConnectionAdapters::Mysql2Adapter.emulate_booleans = false
      class_attribute :emulate_booleans
      self.emulate_booleans = true

      NATIVE_DATABASE_TYPES = {
        primary_key: "int auto_increment PRIMARY KEY",
        string:      { name: "varchar", limit: 255 },
        text:        { name: "text", limit: 65535 },
        integer:     { name: "int", limit: 4 },
        float:       { name: "float" },
        decimal:     { name: "decimal" },
        datetime:    { name: "datetime" },
        time:        { name: "time" },
        date:        { name: "date" },
        binary:      { name: "blob", limit: 65535 },
        boolean:     { name: "tinyint", limit: 1 },
        json:        { name: "json" },
      }

      INDEX_TYPES  = [:fulltext, :spatial]
      INDEX_USINGS = [:btree, :hash]

      class StatementPool < ConnectionAdapters::StatementPool
        private def dealloc(stmt)
          stmt[:stmt].close
        end
      end

      def initialize(connection, logger, connection_options, config)
        super(connection, logger, config)

        @statements = StatementPool.new(self.class.type_cast_config_to_integer(config[:statement_limit]))
        @prepared_statements = false unless config.key?(:prepared_statements)

        configure_connection

        if version < "5.0.0"
          raise "Your version of MySQL (#{full_version.match(/^\d+\.\d+\.\d+/)[0]}) is too old. Active Record supports MySQL >= 5.0."
        end
      end

      CHARSETS_OF_4BYTES_MAXLEN = ["utf8mb4", "utf16", "utf16le", "utf32"]

      def internal_string_options_for_primary_key # :nodoc:
        super.tap { |options|
          options[:collation] = collation.sub(/\A[^_]+/, "utf8") if CHARSETS_OF_4BYTES_MAXLEN.include?(charset)
        }
      end

      def version #:nodoc:
        @version ||= Version.new(full_version.match(/^\d+\.\d+\.\d+/)[0])
      end

      def mariadb? # :nodoc:
        /mariadb/i.match?(full_version)
      end

      # Returns true, since this connection adapter supports migrations.
      def supports_migrations?
        true
      end

      def supports_primary_key?
        true
      end

      def supports_bulk_alter? #:nodoc:
        true
      end

      # Returns true, since this connection adapter supports prepared statement
      # caching.
      def supports_statement_cache?
        true
      end

      # Technically MySQL allows to create indexes with the sort order syntax
      # but at the moment (5.5) it doesn't yet implement them
      def supports_index_sort_order?
        true
      end

      def supports_transaction_isolation?
        true
      end

      def supports_explain?
        true
      end

      def supports_indexes_in_create?
        true
      end

      def supports_foreign_keys?
        true
      end

      def supports_views?
        true
      end

      def supports_datetime_with_precision?
        if mariadb?
          version >= "5.3.0"
        else
          version >= "5.6.4"
        end
      end

      def supports_json?
        !mariadb? && version >= "5.7.8"
      end

      def supports_comments?
        true
      end

      def supports_comments_in_create?
        true
      end

      def supports_savepoints?
        true
      end

      def supports_advisory_locks?
        true
      end

      def get_advisory_lock(lock_name, timeout = 0) # :nodoc:
        select_value("SELECT GET_LOCK(#{quote(lock_name)}, #{timeout})") == 1
      end

      def release_advisory_lock(lock_name) # :nodoc:
        select_value("SELECT RELEASE_LOCK(#{quote(lock_name)})") == 1
      end

      def native_database_types
        NATIVE_DATABASE_TYPES
      end

      def index_algorithms
        { default: "ALGORITHM = DEFAULT", copy: "ALGORITHM = COPY", inplace: "ALGORITHM = INPLACE" }
      end

      # HELPER METHODS ===========================================

      def each_hash(result) # :nodoc:
        if block_given?
          result.each(as: :hash, symbolize_keys: true) do |row|
            yield row
          end
        else
          to_enum(:each_hash, result)
        end
      end

      # Must return the MySQL error number from the exception, if the exception has an
      # error number.
      def error_number(exception) # :nodoc:
        exception.error_number if exception.respond_to?(:error_number)
      end

      # REFERENTIAL INTEGRITY ====================================

      def disable_referential_integrity #:nodoc:
        old = select_value("SELECT @@FOREIGN_KEY_CHECKS")

        begin
          update("SET FOREIGN_KEY_CHECKS = 0")
          yield
        ensure
          update("SET FOREIGN_KEY_CHECKS = #{old}")
        end
      end

      #--
      # CONNECTION MANAGEMENT ====================================
      #++

      def active?
        return false unless @connection
        @connection.ping
      end

      def reconnect!
        super
        disconnect!
        connect
      end
      alias :reset! :reconnect!

      # Disconnects from the database if already connected.
      # Otherwise, this method does nothing.
      def disconnect!
        super
        @connection.close
      end

      # Clears the prepared statements cache.
      def clear_cache!
        reload_type_map
        @statements.clear
      end

      def case_sensitive_comparison(table, attribute, column, value)
        if column.collation && !column.case_sensitive?
          table[attribute].eq(Arel::Nodes::Bin.new(Arel::Nodes::BindParam.new))
        else
          super
        end
      end

      def can_perform_case_insensitive_comparison_for?(column)
        column.case_sensitive?
      end
      private :can_perform_case_insensitive_comparison_for?

      def strict_mode?
        self.class.type_cast_config_to_boolean(@config.fetch(:strict, true))
      end

      def valid_type?(type)
        !native_database_types[type].nil?
      end

      protected

        def initialize_type_map(m) # :nodoc:
          super

          register_class_with_limit m, %r(char)i, MysqlString

          m.register_type %r(tinytext)i,   Type::Text.new(limit: 2**8 - 1)
          m.register_type %r(tinyblob)i,   Type::Binary.new(limit: 2**8 - 1)
          m.register_type %r(text)i,       Type::Text.new(limit: 2**16 - 1)
          m.register_type %r(blob)i,       Type::Binary.new(limit: 2**16 - 1)
          m.register_type %r(mediumtext)i, Type::Text.new(limit: 2**24 - 1)
          m.register_type %r(mediumblob)i, Type::Binary.new(limit: 2**24 - 1)
          m.register_type %r(longtext)i,   Type::Text.new(limit: 2**32 - 1)
          m.register_type %r(longblob)i,   Type::Binary.new(limit: 2**32 - 1)
          m.register_type %r(^float)i,     Type::Float.new(limit: 24)
          m.register_type %r(^double)i,    Type::Float.new(limit: 53)
          m.register_type %r(^json)i,      MysqlJson.new

          register_integer_type m, %r(^bigint)i,    limit: 8
          register_integer_type m, %r(^int)i,       limit: 4
          register_integer_type m, %r(^mediumint)i, limit: 3
          register_integer_type m, %r(^smallint)i,  limit: 2
          register_integer_type m, %r(^tinyint)i,   limit: 1

          m.register_type %r(^tinyint\(1\))i, Type::Boolean.new if emulate_booleans
          m.alias_type %r(year)i,          "integer"
          m.alias_type %r(bit)i,           "binary"

          m.register_type(%r(enum)i) do |sql_type|
            limit = sql_type[/^enum\((.+)\)/i, 1]
              .split(",").map { |enum| enum.strip.length - 2 }.max
            MysqlString.new(limit: limit)
          end

          m.register_type(%r(^set)i) do |sql_type|
            limit = sql_type[/^set\((.+)\)/i, 1]
              .split(",").map { |set| set.strip.length - 1 }.sum - 1
            MysqlString.new(limit: limit)
          end
        end

        def register_integer_type(mapping, key, options) # :nodoc:
          mapping.register_type(key) do |sql_type|
            if /\bunsigned\z/.match?(sql_type)
              Type::UnsignedInteger.new(options)
            else
              Type::Integer.new(options)
            end
          end
        end

        def extract_precision(sql_type)
          if /time/.match?(sql_type)
            super || 0
          else
            super
          end
        end

        # See https://dev.mysql.com/doc/refman/5.7/en/error-messages-server.html
        ER_DUP_ENTRY            = 1062
        ER_NO_REFERENCED_ROW_2  = 1452
        ER_DATA_TOO_LONG        = 1406
        ER_LOCK_DEADLOCK        = 1213

        def translate_exception(exception, message)
          case error_number(exception)
          when ER_DUP_ENTRY
            RecordNotUnique.new(message)
          when ER_NO_REFERENCED_ROW_2
            InvalidForeignKey.new(message)
          when ER_DATA_TOO_LONG
            ValueTooLong.new(message)
          when ER_LOCK_DEADLOCK
            Deadlocked.new(message)
          else
            super
          end
        end

      private

        def supports_rename_index?
          mariadb? ? false : version >= "5.7.6"
        end

        def full_version
          @full_version ||= @connection.server_info[:version]
        end

        def connect
          @connection = Mysql2::Client.new(@config)
          configure_connection
        end

        def configure_connection
          @connection.query_options.merge!(as: :array)

          variables = @config.fetch(:variables, {}).stringify_keys

          # By default, MySQL 'where id is null' selects the last inserted id; Turn this off.
          variables["sql_auto_is_null"] = 0

          # Increase timeout so the server doesn't disconnect us.
          wait_timeout = @config[:wait_timeout]
          wait_timeout = 2147483 unless wait_timeout.is_a?(Integer)
          variables["wait_timeout"] = self.class.type_cast_config_to_integer(wait_timeout)

          defaults = [":default", :default].to_set

          # Make MySQL reject illegal values rather than truncating or blanking them, see
          # http://dev.mysql.com/doc/refman/5.7/en/sql-mode.html#sqlmode_strict_all_tables
          # If the user has provided another value for sql_mode, don't replace it.
          if sql_mode = variables.delete("sql_mode")
            sql_mode = quote(sql_mode)
          elsif !defaults.include?(strict_mode?)
            if strict_mode?
              sql_mode = "CONCAT(@@sql_mode, ',STRICT_ALL_TABLES')"
            else
              sql_mode = "REPLACE(@@sql_mode, 'STRICT_TRANS_TABLES', '')"
              sql_mode = "REPLACE(#{sql_mode}, 'STRICT_ALL_TABLES', '')"
              sql_mode = "REPLACE(#{sql_mode}, 'TRADITIONAL', '')"
            end
            sql_mode = "CONCAT(#{sql_mode}, ',NO_AUTO_VALUE_ON_ZERO')"
          end
          sql_mode_assignment = "@@SESSION.sql_mode = #{sql_mode}, " if sql_mode

          # NAMES does not have an equals sign, see
          # http://dev.mysql.com/doc/refman/5.7/en/set-statement.html#id944430
          # (trailing comma because variable_assignments will always have content)
          if @config[:encoding]
            encoding = "NAMES #{@config[:encoding]}"
            encoding << " COLLATE #{@config[:collation]}" if @config[:collation]
            encoding << ", "
          end

          # Gather up all of the SET variables...
          variable_assignments = variables.map do |k, v|
            if defaults.include?(v)
              "@@SESSION.#{k} = DEFAULT" # Sets the value to the global or compile default
            elsif !v.nil?
              "@@SESSION.#{k} = #{quote(v)}"
            end
            # or else nil; compact to clear nils out
          end.compact.join(", ")

          # ...and send them all in one query
          @connection.query "SET #{encoding} #{sql_mode_assignment} #{variable_assignments}"
        end

        class MysqlJson < Type::Internal::AbstractJson # :nodoc:
          def changed_in_place?(raw_old_value, new_value)
            # Normalization is required because MySQL JSON data format includes
            # the space between the elements.
            super(serialize(deserialize(raw_old_value)), new_value)
          end
        end

        class MysqlString < Type::String # :nodoc:
          def serialize(value)
            case value
            when true then MySQL::Quoting::QUOTED_TRUE
            when false then MySQL::Quoting::QUOTED_FALSE
            else super
            end
          end

          private

            def cast_value(value)
              case value
              when true then MySQL::Quoting::QUOTED_TRUE
              when false then MySQL::Quoting::QUOTED_FALSE
              else super
              end
            end
        end

        ActiveRecord::Type.register(:json, MysqlJson, adapter: :mysql2)
        ActiveRecord::Type.register(:string, MysqlString, adapter: :mysql2)
        ActiveRecord::Type.register(:unsigned_integer, Type::UnsignedInteger, adapter: :mysql2)
    end
  end
end
