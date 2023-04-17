# frozen_string_literal: true

require "active_record/connection_adapters/abstract_mysql_adapter"

gem "trilogy", "~> 2.4"
require "trilogy"

require "active_record/connection_adapters/trilogy/lost_connection_exception_translator"
require "active_record/connection_adapters/trilogy/errors"

module ActiveRecord
  module ConnectionHandling # :nodoc:
    def trilogy_adapter_class
      ConnectionAdapters::TrilogyAdapter
    end

    # Establishes a connection to the database that's used by all Active Record objects.
    def trilogy_connection(config)
      configuration = config.dup

      # Set FOUND_ROWS capability on the connection so UPDATE queries returns number of rows
      # matched rather than number of rows updated.
      configuration[:found_rows] = true

      options = [
        configuration[:host],
        configuration[:port],
        configuration[:database],
        configuration[:username],
        configuration[:password],
        configuration[:socket],
        0
      ]

      trilogy_adapter_class.new nil, logger, options, configuration
    end
  end
  module ConnectionAdapters
    class TrilogyAdapter < AbstractMysqlAdapter
      module DatabaseStatements
        READ_QUERY = AbstractAdapter.build_read_query_regexp(
          :desc, :describe, :set, :show, :use
        ) # :nodoc:
        private_constant :READ_QUERY

        HIGH_PRECISION_CURRENT_TIMESTAMP = Arel.sql("CURRENT_TIMESTAMP(6)").freeze # :nodoc:
        private_constant :HIGH_PRECISION_CURRENT_TIMESTAMP

        def select_all(*, **) # :nodoc:
          result = nil
          with_raw_connection do |conn|
            result = super
            conn.next_result while conn.more_results_exist?
          end
          result
        end

        def write_query?(sql) # :nodoc:
          !READ_QUERY.match?(sql)
        rescue ArgumentError # Invalid encoding
          !READ_QUERY.match?(sql.b)
        end

        def explain(arel, binds = [], options = [])
          sql     = build_explain_clause(options) + " " + to_sql(arel, binds)
          start   = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result  = exec_query(sql, "EXPLAIN", binds)
          elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

          MySQL::ExplainPrettyPrinter.new.pp(result, elapsed)
        end

        def exec_query(sql, name = "SQL", binds = [], prepare: false, async: false)
          result = execute(sql, name, async: async)
          ActiveRecord::Result.new(result.fields, result.to_a)
        end

        alias exec_without_stmt exec_query

        def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
          execute(to_sql(sql, binds), name)
        end

        def exec_delete(sql, name = nil, binds = [])
          result = execute(to_sql(sql, binds), name)
          result.affected_rows
        end

        alias :exec_update :exec_delete

        def high_precision_current_timestamp
          HIGH_PRECISION_CURRENT_TIMESTAMP
        end

        def build_explain_clause(options = [])
          return "EXPLAIN" if options.empty?

          explain_clause = "EXPLAIN #{options.join(" ").upcase}"

          if analyze_without_explain? && explain_clause.include?("ANALYZE")
            explain_clause.sub("EXPLAIN ", "")
          else
            explain_clause
          end
        end

        private
          def last_inserted_id(result)
            result.last_insert_id
          end
      end

      ER_BAD_DB_ERROR = 1049
      ER_DBACCESS_DENIED_ERROR = 1044
      ER_ACCESS_DENIED_ERROR = 1045

      ADAPTER_NAME = "Trilogy"

      include DatabaseStatements

      SSL_MODES = {
        SSL_MODE_DISABLED: ::Trilogy::SSL_DISABLED,
        SSL_MODE_PREFERRED: ::Trilogy::SSL_PREFERRED_NOVERIFY,
        SSL_MODE_REQUIRED: ::Trilogy::SSL_REQUIRED_NOVERIFY,
        SSL_MODE_VERIFY_CA: ::Trilogy::SSL_VERIFY_CA,
        SSL_MODE_VERIFY_IDENTITY: ::Trilogy::SSL_VERIFY_IDENTITY
      }.freeze

      class << self
        def new_client(config)
          config[:ssl_mode] = parse_ssl_mode(config[:ssl_mode]) if config[:ssl_mode]
          ::Trilogy.new(config)
        rescue ::Trilogy::ConnectionError, ::Trilogy::ProtocolError => error
          raise translate_connect_error(config, error)
        end

        def parse_ssl_mode(mode)
          return mode if mode.is_a? Integer

          m = mode.to_s.upcase
          # enable Mysql2 client compatibility
          m = "SSL_MODE_#{m}" unless m.start_with? "SSL_MODE_"

          SSL_MODES.fetch(m.to_sym, mode)
        end

        def translate_connect_error(config, error)
          case error.error_code
          when ER_DBACCESS_DENIED_ERROR, ER_BAD_DB_ERROR
            ActiveRecord::NoDatabaseError.db_error(config[:database])
          when ER_ACCESS_DENIED_ERROR
            ActiveRecord::DatabaseConnectionError.username_error(config[:username])
          else
            if error.message.include?(/TRILOGY_DNS_ERROR/)
              ActiveRecord::DatabaseConnectionError.hostname_error(config[:host])
            else
              ActiveRecord::ConnectionNotEstablished.new(error.message)
            end
          end
        end
      end

      def supports_json?
        !mariadb? && database_version >= "5.7.8"
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

      def savepoint_errors_invalidate_transactions?
        true
      end

      def supports_lazy_transactions?
        true
      end

      def quote_string(string)
        with_raw_connection(allow_retry: true, uses_transaction: false) do |conn|
          conn.escape(string)
        end
      end

      def active?
        connection&.ping || false
      rescue ::Trilogy::Error
        false
      end

      alias reset! reconnect!

      def disconnect!
        super
        unless connection.nil?
          connection.close
          self.connection = nil
        end
      end

      def discard!
        self.connection = nil
      end

      def each_hash(result)
        return to_enum(:each_hash, result) unless block_given?

        keys = result.fields.map(&:to_sym)
        result.rows.each do |row|
          hash = {}
          idx = 0
          row.each do |value|
            hash[keys[idx]] = value
            idx += 1
          end
          yield hash
        end

        nil
      end

      def error_number(exception)
        exception.error_code if exception.respond_to?(:error_code)
      end

      private
        def connection
          @raw_connection
        end

        def connection=(conn)
          @raw_connection = conn
        end

        def connect
          self.connection = self.class.new_client(@config)
        end

        def reconnect
          connection&.close
          self.connection = nil
          connect
        end

        def sync_timezone_changes(conn)
          # Sync any changes since connection last established.
          if default_timezone == :local
            conn.query_flags |= ::Trilogy::QUERY_FLAGS_LOCAL_TIMEZONE
          else
            conn.query_flags &= ~::Trilogy::QUERY_FLAGS_LOCAL_TIMEZONE
          end
        end

        def execute_batch(statements, name = nil)
          statements = statements.map { |sql| transform_query(sql) }
          combine_multi_statements(statements).each do |statement|
            with_raw_connection do |conn|
              raw_execute(statement, name)
              conn.next_result while conn.more_results_exist?
            end
          end
        end

        def multi_statements_enabled?
          !!@config[:multi_statement]
        end

        def with_multi_statements
          if multi_statements_enabled?
            return yield
          end

          with_raw_connection do |conn|
            conn.set_server_option(::Trilogy::SET_SERVER_MULTI_STATEMENTS_ON)

            yield
          ensure
            conn.set_server_option(::Trilogy::SET_SERVER_MULTI_STATEMENTS_OFF)
          end
        end

        def combine_multi_statements(total_sql)
          total_sql.each_with_object([]) do |sql, total_sql_chunks|
            previous_packet = total_sql_chunks.last
            if max_allowed_packet_reached?(sql, previous_packet)
              total_sql_chunks << +sql
            else
              previous_packet << ";\n"
              previous_packet << sql
            end
          end
        end

        def max_allowed_packet_reached?(current_packet, previous_packet)
          if current_packet.bytesize > max_allowed_packet
            raise ActiveRecordError,
              "Fixtures set is too large #{current_packet.bytesize}. Consider increasing the max_allowed_packet variable."
          elsif previous_packet.nil?
            true
          else
            (current_packet.bytesize + previous_packet.bytesize + 2) > max_allowed_packet
          end
        end

        def max_allowed_packet
          @max_allowed_packet ||= show_variable("max_allowed_packet")
        end

        def full_version
          schema_cache.database_version.full_version_string
        end

        def get_full_version
          with_raw_connection(allow_retry: true, uses_transaction: false) do |conn|
            conn.server_info[:version]
          end
        end

        def translate_exception(exception, message:, sql:, binds:)
          error_code = exception.error_code if exception.respond_to?(:error_code)

          Trilogy::LostConnectionExceptionTranslator.new(exception, message, error_code).translate || super
        end

        def default_prepared_statements
          false
        end

        def default_insert_value(column)
          super unless column.auto_increment?
        end

        # https://mariadb.com/kb/en/analyze-statement/
        def analyze_without_explain?
          mariadb? && database_version >= "10.1.0"
        end
    end
  end
end
