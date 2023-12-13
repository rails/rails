# frozen_string_literal: true

require "active_record/connection_adapters/abstract_mysql_adapter"

gem "trilogy", "~> 2.4"
require "trilogy"

require "active_record/connection_adapters/trilogy/database_statements"

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
      ER_BAD_DB_ERROR = 1049
      ER_DBACCESS_DENIED_ERROR = 1044
      ER_ACCESS_DENIED_ERROR = 1045
      ER_SERVER_SHUTDOWN = 1053

      ADAPTER_NAME = "Trilogy"

      include Trilogy::DatabaseStatements

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
        rescue ::Trilogy::Error => error
          raise translate_connect_error(config, error)
        end

        def parse_ssl_mode(mode)
          return mode if mode.is_a? Integer

          m = mode.to_s.upcase
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
            if error.message.include?("TRILOGY_DNS_ERROR")
              ActiveRecord::DatabaseConnectionError.hostname_error(config[:host])
            else
              ActiveRecord::ConnectionNotEstablished.new(error.message)
            end
          end
        end

        private
          def initialize_type_map(m)
            super

            m.register_type(%r(char)i) do |sql_type|
              limit = extract_limit(sql_type)
              Type.lookup(:string, adapter: :trilogy, limit: limit)
            end

            m.register_type %r(^enum)i, Type.lookup(:string, adapter: :trilogy)
            m.register_type %r(^set)i,  Type.lookup(:string, adapter: :trilogy)
          end
      end

      def initialize(...)
        super

        # Trilogy ignore `socket` if `host is set. We want the opposite to allow
        # configuring UNIX domain sockets via `DATABASE_URL`.
        @config.delete(:host) if @config[:socket]
      end

      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) }

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
        with_raw_connection(allow_retry: true, materialize_transactions: false) do |conn|
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
        super
        unless connection.nil?
          connection.discard!
          self.connection = nil
        end
      end

      private
        def text_type?(type)
          TYPE_MAP.lookup(type).is_a?(Type::String) || TYPE_MAP.lookup(type).is_a?(Type::Text)
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

        def connection
          @raw_connection
        end

        def connection=(conn)
          @raw_connection = conn
        end

        def connect
          self.connection = self.class.new_client(@config)
        rescue ConnectionNotEstablished => ex
          raise ex.set_pool(@pool)
        end

        def reconnect
          connection&.close
          self.connection = nil
          connect
        end

        def full_version
          schema_cache.database_version.full_version_string
        end

        def get_full_version
          with_raw_connection(allow_retry: true, materialize_transactions: false) do |conn|
            conn.server_info[:version]
          end
        end

        def translate_exception(exception, message:, sql:, binds:)
          if exception.is_a?(::Trilogy::TimeoutError) && !exception.error_code
            return ActiveRecord::AdapterTimeout.new(message, sql: sql, binds: binds, connection_pool: @pool)
          end
          error_code = exception.error_code if exception.respond_to?(:error_code)

          case error_code
          when ER_SERVER_SHUTDOWN
            return ConnectionFailed.new(message, connection_pool: @pool)
          end

          case exception
          when Errno::EPIPE, SocketError, IOError
            return ConnectionFailed.new(message, connection_pool: @pool)
          when ::Trilogy::Error
            if /Connection reset by peer|TRILOGY_CLOSED_CONNECTION|TRILOGY_INVALID_SEQUENCE_ID|TRILOGY_UNEXPECTED_PACKET/.match?(exception.message)
              return ConnectionFailed.new(message, connection_pool: @pool)
            end
          end

          super
        end

        def default_prepared_statements
          false
        end

        ActiveRecord::Type.register(:immutable_string, adapter: :trilogy) do |_, **args|
          Type::ImmutableString.new(true: "1", false: "0", **args)
        end

        ActiveRecord::Type.register(:string, adapter: :trilogy) do |_, **args|
          Type::String.new(true: "1", false: "0", **args)
        end

        ActiveRecord::Type.register(:unsigned_integer, Type::UnsignedInteger, adapter: :trilogy)
    end

    ActiveSupport.run_load_hooks(:active_record_trilogyadapter, TrilogyAdapter)
  end
end
