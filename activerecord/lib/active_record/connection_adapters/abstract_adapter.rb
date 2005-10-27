require 'benchmark'
require 'date'

require 'active_record/connection_adapters/abstract/schema_definitions'
require 'active_record/connection_adapters/abstract/schema_statements'
require 'active_record/connection_adapters/abstract/database_statements'
require 'active_record/connection_adapters/abstract/quoting'
require 'active_record/connection_adapters/abstract/connection_specification'

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # All the concrete database adapters follow the interface laid down in this class.
    # You can use this interface directly by borrowing the database connection from the Base with
    # Base.connection.
    #
    # Most of the methods in the adapter are useful during migrations.  Most
    # notably, SchemaStatements#create_table, SchemaStatements#drop_table,
    # SchemaStatements#add_index, SchemaStatements#remove_index,
    # SchemaStatements#add_column, SchemaStatements#change_column and
    # SchemaStatements#remove_column are very useful.
    class AbstractAdapter
      include Quoting, DatabaseStatements, SchemaStatements
      @@row_even = true

      def initialize(connection, logger = nil) #:nodoc:
        @connection, @logger = connection, logger
        @runtime = 0
      end

      # Returns the human-readable name of the adapter.  Use mixed case - one
      # can always use downcase if needed.
      def adapter_name
        'Abstract'
      end
      
      # Does this adapter support migrations?  Backend specific, as the
      # abstract adapter always returns +false+.
      def supports_migrations?
        false
      end

      def reset_runtime #:nodoc:
        rt = @runtime
        @runtime = 0
        return rt
      end

      protected  
        def log(sql, name)
          begin
            if block_given?
              if @logger and @logger.level <= Logger::INFO
                result = nil
                seconds = Benchmark.realtime { result = yield }
                @runtime += seconds
                log_info(sql, name, seconds)
                result
              else
                yield
              end
            else
              log_info(sql, name, 0)
              nil
            end
          rescue Exception => e
            log_info("#{e.message}: #{sql}", name, 0)
            raise ActiveRecord::StatementInvalid, "#{e.message}: #{sql}"
          end
        end

        def log_info(sql, name, runtime)
          return unless @logger

          @logger.debug(
            format_log_entry(
              "#{name.nil? ? "SQL" : name} (#{sprintf("%f", runtime)})",
              sql.gsub(/ +/, " ")
            )
          )
        end

        def format_log_entry(message, dump = nil)
          if ActiveRecord::Base.colorize_logging
            if @@row_even
              @@row_even = false
              message_color, dump_color = "4;36;1", "0;1"
            else
              @@row_even = true
              message_color, dump_color = "4;35;1", "0"
            end

            log_entry = "  \e[#{message_color}m#{message}\e[0m   "
            log_entry << "\e[#{dump_color}m%#{String === dump ? 's' : 'p'}\e[0m" % dump if dump
            log_entry
          else
            "%s  %s" % [message, dump]
          end
        end
    end
  end
end
