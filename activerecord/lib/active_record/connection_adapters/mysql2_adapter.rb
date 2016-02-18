require 'active_record/connection_adapters/abstract_mysql_adapter'

gem 'mysql2', '>= 0.3.18', '< 0.5'
require 'mysql2'

module ActiveRecord
  module ConnectionHandling # :nodoc:
    # Establishes a connection to the database that's used by all Active Record objects.
    def mysql2_connection(config)
      config = config.symbolize_keys

      config[:username] = 'root' if config[:username].nil?
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
    class Mysql2Adapter < AbstractMysqlAdapter
      ADAPTER_NAME = 'Mysql2'.freeze

      def initialize(connection, logger, connection_options, config)
        super
        @prepared_statements = false
        configure_connection
      end

      def supports_json?
        !mariadb? && version >= '5.7.8'
      end

      # HELPER METHODS ===========================================

      def each_hash(result) # :nodoc:
        if block_given?
          result.each(:as => :hash, :symbolize_keys => true) do |row|
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
        unless @connection.nil?
          @connection.close
          @connection = nil
        end
      end

      #--
      # DATABASE STATEMENTS ======================================
      #++

      # Returns a record hash with the column names as keys and column values
      # as values.
      def select_one(arel, name = nil, binds = [])
        arel, binds = binds_from_relation(arel, binds)
        execute(to_sql(arel, binds), name).each(as: :hash) do |row|
          @connection.next_result while @connection.more_results?
          return row
        end
      end

      # Returns an array of arrays containing the field values.
      # Order is the same as that returned by +columns+.
      def select_rows(sql, name = nil, binds = [])
        result = execute(sql, name)
        @connection.next_result while @connection.more_results?
        result.to_a
      end

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil)
        if @connection
          # make sure we carry over any changes to ActiveRecord::Base.default_timezone that have been
          # made since we established the connection
          @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone
        end

        super
      end

      def exec_query(sql, name = 'SQL', binds = [], prepare: false)
        result = execute(sql, name)
        @connection.next_result while @connection.more_results?
        ActiveRecord::Result.new(result.fields, result.to_a)
      end

      def exec_insert(sql, name, binds, pk = nil, sequence_name = nil)
        execute to_sql(sql, binds), name
      end

      def exec_delete(sql, name, binds)
        execute to_sql(sql, binds), name
        @connection.affected_rows
      end
      alias :exec_update :exec_delete

      def last_inserted_id(result)
        @connection.last_id
      end

      private

      def connect
        @connection = Mysql2::Client.new(@config)
        configure_connection
      end

      def configure_connection
        @connection.query_options.merge!(:as => :array)
        super
      end

      def full_version
        @full_version ||= @connection.server_info[:version]
      end
    end
  end
end
