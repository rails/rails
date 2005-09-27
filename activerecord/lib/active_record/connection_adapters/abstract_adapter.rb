require 'benchmark'
require 'date'

require 'active_record/connection_adapters/abstract/schema_definitions'
require 'active_record/connection_adapters/abstract/schema_statements'
require 'active_record/connection_adapters/abstract/database_statements'
require 'active_record/connection_adapters/abstract/quoting'
require 'active_record/connection_adapters/abstract/connection_specification'

# Method that requires a library, ensuring that rubygems is loaded
# This is used in the database adaptors to require DB drivers. Reasons:
# (1) database drivers are the only third-party library that Rails depend upon
# (2) they are often installed as gems
def require_library_or_gem(library_name)
  begin
    require library_name
  rescue LoadError => cannot_require
    # 1. Requiring the module is unsuccessful, maybe it's a gem and nobody required rubygems yet. Try.
    begin
      require 'rubygems'
    rescue LoadError => rubygems_not_installed
      raise cannot_require
    end
    # 2. Rubygems is installed and loaded. Try to load the library again
    begin
      require library_name
    rescue LoadError => gem_not_installed
      raise cannot_require
    end
  end
end

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
      
      # Does this adapter support migrations ?  Backend specific, as the
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
            if @@row_even then
              @@row_even = false; caller_color = "1;32"; message_color = "4;33"; dump_color = "1;37"
            else
              @@row_even = true; caller_color = "1;36"; message_color = "4;35"; dump_color = "0;37"
            end

            log_entry = "  \e[#{message_color}m#{message}\e[m"
            log_entry << "   \e[#{dump_color}m%s\e[m" % dump if dump.kind_of?(String) && !dump.nil?
            log_entry << "   \e[#{dump_color}m%p\e[m" % dump if !dump.kind_of?(String) && !dump.nil?
            log_entry
          else
            "%s  %s" % [message, dump]
          end
        end
    end
  end
end
