require 'active_record/connection_adapters/abstract_mysql_adapter'

gem 'mysql2', '~> 0.3.6'
require 'mysql2'

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.mysql2_connection(config)
      config[:username] = 'root' if config[:username].nil?

      if Mysql2::Client.const_defined? :FOUND_ROWS
        config[:flags] = Mysql2::Client::FOUND_ROWS
      end

      client = Mysql2::Client.new(config.symbolize_keys)
      options = [config[:host], config[:username], config[:password], config[:database], config[:port], config[:socket], 0]
      ConnectionAdapters::Mysql2Adapter.new(client, logger, options, config)
    end
  end

  module ConnectionAdapters
    class Mysql2Adapter < AbstractMysqlAdapter

      class Column < AbstractMysqlAdapter::Column # :nodoc:
        def adapter
          Mysql2Adapter
        end
      end

      ADAPTER_NAME = 'Mysql2'

      def initialize(connection, logger, connection_options, config)
        super
        configure_connection
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

      def new_column(field, default, type, null) # :nodoc:
        Column.new(field, default, type, null)
      end

      def error_number(exception)
        exception.error_number if exception.respond_to?(:error_number)
      end

      # QUOTING ==================================================

      def quote_string(string)
        @connection.escape(string)
      end

      def substitute_at(column, index)
        Arel.sql "\0"
      end

      # CONNECTION MANAGEMENT ====================================

      def active?
        return false unless @connection
        @connection.ping
      end

      def reconnect!
        disconnect!
        connect
      end

      # Disconnects from the database if already connected.
      # Otherwise, this method does nothing.
      def disconnect!
        unless @connection.nil?
          @connection.close
          @connection = nil
        end
      end

      def reset!
        disconnect!
        connect
      end

      # DATABASE STATEMENTS ======================================

      # FIXME: re-enable the following once a "better" query_cache solution is in core
      #
      # The overrides below perform much better than the originals in AbstractAdapter
      # because we're able to take advantage of mysql2's lazy-loading capabilities
      #
      # # Returns a record hash with the column names as keys and column values
      # # as values.
      # def select_one(sql, name = nil)
      #   result = execute(sql, name)
      #   result.each(:as => :hash) do |r|
      #     return r
      #   end
      # end
      #
      # # Returns a single value from a record
      # def select_value(sql, name = nil)
      #   result = execute(sql, name)
      #   if first = result.first
      #     first.first
      #   end
      # end
      #
      # # Returns an array of the values of the first column in a select:
      # #   select_values("SELECT id FROM companies LIMIT 3") => [1,2,3]
      # def select_values(sql, name = nil)
      #   execute(sql, name).map { |row| row.first }
      # end

      # Returns an array of arrays containing the field values.
      # Order is the same as that returned by +columns+.
      def select_rows(sql, name = nil)
        execute(sql, name).to_a
      end

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil)
        # make sure we carry over any changes to ActiveRecord::Base.default_timezone that have been
        # made since we established the connection
        @connection.query_options[:database_timezone] = ActiveRecord::Base.default_timezone

        super
      end

      def exec_query(sql, name = 'SQL', binds = [])
        result = execute(sql, name)
        ActiveRecord::Result.new(result.fields, result.to_a)
      end

      alias exec_without_stmt exec_query

      # Returns an array of record hashes with the column names as keys and
      # column values as values.
      def select(sql, name = nil, binds = [])
        binds = binds.dup
        exec_query(sql.gsub("\0") { quote(*binds.shift.reverse) }, name).to_a
      end

      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        super
        id_value || @connection.last_id
      end
      alias :create :insert_sql

      def exec_insert(sql, name, binds)
        binds = binds.dup

        # Pretend to support bind parameters
        execute sql.gsub("\0") { quote(*binds.shift.reverse) }, name
      end

      def exec_delete(sql, name, binds)
        binds = binds.dup

        # Pretend to support bind parameters
        execute sql.gsub("\0") { quote(*binds.shift.reverse) }, name
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

        # By default, MySQL 'where id is null' selects the last inserted id.
        # Turn this off. http://dev.rubyonrails.org/ticket/6778
        variable_assignments = ['SQL_AUTO_IS_NULL=0']
        encoding = @config[:encoding]

        # make sure we set the encoding
        variable_assignments << "NAMES '#{encoding}'" if encoding

        # increase timeout so mysql server doesn't disconnect us
        wait_timeout = @config[:wait_timeout]
        wait_timeout = 2592000 unless wait_timeout.is_a?(Fixnum)
        variable_assignments << "@@wait_timeout = #{wait_timeout}"

        execute("SET #{variable_assignments.join(', ')}", :skip_logging)
      end

      def version
        @version ||= @connection.info[:version].scan(/^(\d+)\.(\d+)\.(\d+)/).flatten.map { |v| v.to_i }
      end
    end
  end
end
