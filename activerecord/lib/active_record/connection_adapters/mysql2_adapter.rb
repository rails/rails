# frozen_string_literal: true

require "active_record/connection_adapters/abstract_mysql_adapter"
require "active_record/connection_adapters/mysql/database_statements"

gem "mysql2", ">= 0.4.4"
require "mysql2"

module ActiveRecord
  module ConnectionHandling # :nodoc:
    ER_BAD_DB_ERROR = 1049

    # Establishes a connection to the database that's used by all Active Record objects.
    def mysql2_connection(config)
      config = config.symbolize_keys
      config[:flags] ||= 0

      if config[:flags].kind_of? Array
        config[:flags].push "FOUND_ROWS"
      else
        config[:flags] |= Mysql2::Client::FOUND_ROWS
      end

      client = Mysql2::Client.new(config)
      ConnectionAdapters::Mysql2Adapter.new(client, logger, nil, config)
    rescue Mysql2::Error => error
      if error.error_number == ER_BAD_DB_ERROR
        raise ActiveRecord::NoDatabaseError
      else
        raise
      end
    end
  end

  module ConnectionAdapters
    class Mysql2Adapter < AbstractMysqlAdapter
      ADAPTER_NAME = "Mysql2"

      include MySQL::DatabaseStatements

      def initialize(connection, logger, connection_options, config)
        superclass_config = config.reverse_merge(prepared_statements: false)
        super(connection, logger, connection_options, superclass_config)
        configure_connection
      end

      def self.database_exists?(config)
        !!ActiveRecord::Base.mysql2_connection(config)
      rescue ActiveRecord::NoDatabaseError
        false
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

      def supports_lazy_transactions?
        true
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

      def error_number(exception)
        exception.error_number if exception.respond_to?(:error_number)
      end

      #--
      # QUOTING ==================================================
      #++

      def quote_string(string)
        @connection.escape(string)
      end

      #--
      # CONNECTION MANAGEMENT ====================================
      #++

      def active?
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

      def discard! # :nodoc:
        super
        @connection.automatic_close = false
        @connection = nil
      end

      private
        def connect
          @connection = Mysql2::Client.new(@config)
          configure_connection
        end

        def configure_connection
          @connection.query_options[:as] = :array
          super
        end

        def full_version
          schema_cache.database_version.full_version_string
        end

        def get_full_version
          @connection.server_info[:version]
        end
    end
  end
end
