require 'active_record/connection_adapters/abstract_mysql_adapter'

gem 'mysql2', '~> 0.3.10'
require 'mysql2'

module ActiveRecord
  module ConnectionHandling # :nodoc:
    # Establishes a connection to the database that's used by all Active Record objects.
    def mysql2_connection(config)
      config = config.symbolize_keys

      config[:username] = 'root' if config[:username].nil?

      if Mysql2::Client.const_defined? :FOUND_ROWS
        config[:flags] = Mysql2::Client::FOUND_ROWS
      end

      client = Mysql2::Client.new(config)
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
        @visitor = BindSubstitution.new self
        configure_connection
      end

      MAX_INDEX_LENGTH_FOR_UTF8MB4 = 191
      def initialize_schema_migrations_table
        if @config[:encoding] == 'utf8mb4'
          ActiveRecord::SchemaMigration.create_table(MAX_INDEX_LENGTH_FOR_UTF8MB4)
        else
          ActiveRecord::SchemaMigration.create_table
        end
      end

      def supports_explain?
        true
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

      def new_column(field, default, type, null, collation, extra = "") # :nodoc:
        Column.new(field, default, type, null, collation, strict_mode?, extra)
      end

      def error_number(exception)
        exception.error_number if exception.respond_to?(:error_number)
      end

      # QUOTING ==================================================

      def quote_string(string)
        @connection.escape(string)
      end

      # CONNECTION MANAGEMENT ====================================

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

      # DATABASE STATEMENTS ======================================

      def explain(arel, binds = [])
        sql     = "EXPLAIN #{to_sql(arel, binds.dup)}"
        start   = Time.now
        result  = exec_query(sql, 'EXPLAIN', binds)
        elapsed = Time.now - start

        ExplainPrettyPrinter.new.pp(result, elapsed)
      end

      class ExplainPrettyPrinter # :nodoc:
        # Pretty prints the result of a EXPLAIN in a way that resembles the output of the
        # MySQL shell:
        #
        #   +----+-------------+-------+-------+---------------+---------+---------+-------+------+-------------+
        #   | id | select_type | table | type  | possible_keys | key     | key_len | ref   | rows | Extra       |
        #   +----+-------------+-------+-------+---------------+---------+---------+-------+------+-------------+
        #   |  1 | SIMPLE      | users | const | PRIMARY       | PRIMARY | 4       | const |    1 |             |
        #   |  1 | SIMPLE      | posts | ALL   | NULL          | NULL    | NULL    | NULL  |    1 | Using where |
        #   +----+-------------+-------+-------+---------------+---------+---------+-------+------+-------------+
        #   2 rows in set (0.00 sec)
        #
        # This is an exercise in Ruby hyperrealism :).
        def pp(result, elapsed)
          widths    = compute_column_widths(result)
          separator = build_separator(widths)

          pp = []

          pp << separator
          pp << build_cells(result.columns, widths)
          pp << separator

          result.rows.each do |row|
            pp << build_cells(row, widths)
          end

          pp << separator
          pp << build_footer(result.rows.length, elapsed)

          pp.join("\n") + "\n"
        end

        private

        def compute_column_widths(result)
          [].tap do |widths|
            result.columns.each_with_index do |column, i|
              cells_in_column = [column] + result.rows.map {|r| r[i].nil? ? 'NULL' : r[i].to_s}
              widths << cells_in_column.map(&:length).max
            end
          end
        end

        def build_separator(widths)
          padding = 1
          '+' + widths.map {|w| '-' * (w + (padding*2))}.join('+') + '+'
        end

        def build_cells(items, widths)
          cells = []
          items.each_with_index do |item, i|
            item = 'NULL' if item.nil?
            justifier = item.is_a?(Numeric) ? 'rjust' : 'ljust'
            cells << item.to_s.send(justifier, widths[i])
          end
          '| ' + cells.join(' | ') + ' |'
        end

        def build_footer(nrows, elapsed)
          rows_label = nrows == 1 ? 'row' : 'rows'
          "#{nrows} #{rows_label} in set (%.2f sec)" % elapsed
        end
      end

      # FIXME: re-enable the following once a "better" query_cache solution is in core
      #
      # The overrides below perform much better than the originals in AbstractAdapter
      # because we're able to take advantage of mysql2's lazy-loading capabilities
      #
      # # Returns a record hash with the column names as keys and column values
      # # as values.
      # def select_one(sql, name = nil)
      #   result = execute(sql, name)
      #   result.each(as: :hash) do |r|
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
      def select_rows(sql, name = nil, binds = [])
        execute(sql, name).to_a
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

      def exec_query(sql, name = 'SQL', binds = [])
        result = execute(sql, name)
        ActiveRecord::Result.new(result.fields, result.to_a)
      end

      alias exec_without_stmt exec_query

      # Returns an array of record hashes with the column names as keys and
      # column values as values.
      def select(sql, name = nil, binds = [])
        exec_query(sql, name)
      end

      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
        super
        id_value || @connection.last_id
      end
      alias :create :insert_sql

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

      def version
        @version ||= @connection.info[:version].scan(/^(\d+)\.(\d+)\.(\d+)/).flatten.map { |v| v.to_i }
      end

      def set_field_encoding field_name
        field_name
      end
    end
  end
end
