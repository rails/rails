# frozen_string_literal: true

require "active_record/connection_adapters/abstract_mysql_adapter"
require "active_record/connection_adapters/mysql2/database_statements"

gem "mysql2", "~> 0.5"
require "mysql2"

module ActiveRecord
  module ConnectionAdapters
    # = Active Record MySQL2 Adapter
    class Mysql2Adapter < AbstractMysqlAdapter
      ER_BAD_DB_ERROR           = 1049
      ER_DBACCESS_DENIED_ERROR  = 1044
      ER_ACCESS_DENIED_ERROR    = 1045
      ER_CONN_HOST_ERROR        = 2003
      ER_UNKNOWN_HOST_ERROR     = 2005

      ADAPTER_NAME = "Mysql2"

      include Mysql2::DatabaseStatements

      class << self
        def new_client(config)
          ::Mysql2::Client.new(config)
        rescue ::Mysql2::Error => error
          case error.error_number
          when ER_BAD_DB_ERROR
            raise ActiveRecord::NoDatabaseError.db_error(config[:database])
          when ER_DBACCESS_DENIED_ERROR, ER_ACCESS_DENIED_ERROR
            raise ActiveRecord::DatabaseConnectionError.username_error(config[:username])
          when ER_CONN_HOST_ERROR, ER_UNKNOWN_HOST_ERROR
            raise ActiveRecord::DatabaseConnectionError.hostname_error(config[:host])
          else
            raise ActiveRecord::ConnectionNotEstablished, error.message
          end
        end

        private
          def initialize_type_map(m)
            super

            m.register_type(%r(char)i) do |sql_type|
              limit = extract_limit(sql_type)
              Type.lookup(:string, adapter: :mysql2, limit: limit)
            end

            m.register_type %r(^enum)i, Type.lookup(:string, adapter: :mysql2)
            m.register_type %r(^set)i,  Type.lookup(:string, adapter: :mysql2)
          end
      end

      TYPE_MAP = Type::TypeMap.new.tap { |m| initialize_type_map(m) }

      def initialize(...)
        super

        @affected_rows_before_warnings = nil
        @config[:flags] ||= 0

        if @config[:flags].kind_of? Array
          @config[:flags].push "FOUND_ROWS"
        else
          @config[:flags] |= ::Mysql2::Client::FOUND_ROWS
        end

        @connection_parameters ||= @config
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

      # HELPER METHODS ===========================================

      def error_number(exception)
        exception.error_number if exception.respond_to?(:error_number)
      end

      #--
      # CONNECTION MANAGEMENT ====================================
      #++

      def connected?
        !(@raw_connection.nil? || @raw_connection.closed?)
      end

      def active?
        if connected?
          @lock.synchronize do
            if @raw_connection&.ping
              verified!
              true
            end
          end
        end || false
      end

      alias :reset! :reconnect!

      # Disconnects from the database if already connected.
      # Otherwise, this method does nothing.
      def disconnect!
        @lock.synchronize do
          super
          @raw_connection&.close
          @raw_connection = nil
        end
      end

      def discard! # :nodoc:
        @lock.synchronize do
          super
          @raw_connection&.automatic_close = false
          @raw_connection = nil
        end
      end

      private
        def text_type?(type)
          TYPE_MAP.lookup(type).is_a?(Type::String) || TYPE_MAP.lookup(type).is_a?(Type::Text)
        end

        def connect
          @raw_connection = self.class.new_client(@connection_parameters)
        rescue ConnectionNotEstablished => ex
          raise ex.set_pool(@pool)
        end

        def reconnect
          @lock.synchronize do
            @raw_connection&.close
            @raw_connection = nil
            connect
          end
        end

        def configure_connection
          @raw_connection.query_options[:as] = :array
          @raw_connection.query_options[:database_timezone] = default_timezone
          super
        end

        def full_version
          database_version.full_version_string
        end

        def get_full_version
          any_raw_connection.server_info[:version]
        end

        def translate_exception(exception, message:, sql:, binds:)
          if exception.is_a?(::Mysql2::Error::TimeoutError) && !exception.error_number
            ActiveRecord::AdapterTimeout.new(message, sql: sql, binds: binds, connection_pool: @pool)
          elsif exception.is_a?(::Mysql2::Error::ConnectionError)
            if exception.message.match?(/MySQL client is not connected/i)
              ActiveRecord::ConnectionNotEstablished.new(exception, connection_pool: @pool)
            else
              ActiveRecord::ConnectionFailed.new(message, sql: sql, binds: binds, connection_pool: @pool)
            end
          else
            super
          end
        end

        def default_prepared_statements
          false
        end

        ActiveRecord::Type.register(:immutable_string, adapter: :mysql2) do |_, **args|
          Type::ImmutableString.new(true: "1", false: "0", **args)
        end

        ActiveRecord::Type.register(:string, adapter: :mysql2) do |_, **args|
          Type::String.new(true: "1", false: "0", **args)
        end

        ActiveRecord::Type.register(:unsigned_integer, Type::UnsignedInteger, adapter: :mysql2)
    end

    ActiveSupport.run_load_hooks(:active_record_mysql2adapter, Mysql2Adapter)
  end
end
