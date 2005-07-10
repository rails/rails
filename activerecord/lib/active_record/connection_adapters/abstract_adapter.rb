require 'benchmark'
require 'date'

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
  class Base
    class ConnectionSpecification #:nodoc:
      attr_reader :config, :adapter_method
      def initialize (config, adapter_method)
        @config, @adapter_method = config, adapter_method
      end
    end

    # The class -> [adapter_method, config] map
    @@defined_connections = {}

    # Establishes the connection to the database. Accepts a hash as input where
    # the :adapter key must be specified with the name of a database adapter (in lower-case)
    # example for regular databases (MySQL, Postgresql, etc):
    #
    #   ActiveRecord::Base.establish_connection(
    #     :adapter  => "mysql",
    #     :host     => "localhost",
    #     :username => "myuser",
    #     :password => "mypass",
    #     :database => "somedatabase"
    #   )
    #
    # Example for SQLite database:
    #
    #   ActiveRecord::Base.establish_connection(
    #     :adapter => "sqlite",
    #     :dbfile  => "path/to/dbfile"
    #   )
    #
    # Also accepts keys as strings (for parsing from yaml for example):
    #   ActiveRecord::Base.establish_connection(
    #     "adapter" => "sqlite",
    #     "dbfile"  => "path/to/dbfile"
    #   )
    #
    # The exceptions AdapterNotSpecified, AdapterNotFound and ArgumentError
    # may be returned on an error.
    def self.establish_connection(spec = nil)
      case spec
        when nil
          raise AdapterNotSpecified unless defined? RAILS_ENV
          establish_connection(RAILS_ENV)
        when ConnectionSpecification
          @@defined_connections[self] = spec
        when Symbol, String
          if configuration = configurations[spec.to_s]
            establish_connection(configuration)
          else
            raise AdapterNotSpecified, "#{spec} database is not configured"
          end
        else
          spec = spec.symbolize_keys
          unless spec.key?(:adapter) then raise AdapterNotSpecified, "database configuration does not specify adapter" end
          adapter_method = "#{spec[:adapter]}_connection"
          unless respond_to?(adapter_method) then raise AdapterNotFound, "database configuration specifies nonexistent #{spec[:adapter]} adapter" end
          remove_connection
          establish_connection(ConnectionSpecification.new(spec, adapter_method))
      end
    end

    def self.active_connections #:nodoc:
      if threaded_connections
        Thread.current['active_connections'] ||= {}
      else
        @@active_connections ||= {}
      end
    end

    # Locate the connection of the nearest super class. This can be an
    # active or defined connections: if it is the latter, it will be
    # opened and set as the active connection for the class it was defined
    # for (not necessarily the current class).
    def self.retrieve_connection #:nodoc:
      klass = self
      ar_super = ActiveRecord::Base.superclass
      until klass == ar_super
        if conn = active_connections[klass]
          return conn
        elsif conn = @@defined_connections[klass]
          klass.connection = conn
          return self.connection
        end
        klass = klass.superclass
      end
      raise ConnectionNotEstablished
    end

    # Returns true if a connection that's accessible to this class have already been opened.
    def self.connected?
      klass = self
      until klass == ActiveRecord::Base.superclass
        if active_connections[klass]
          return true
        else
          klass = klass.superclass
        end
      end
      return false
    end

    # Remove the connection for this class. This will close the active
    # connection and the defined connection (if they exist). The result
    # can be used as argument for establish_connection, for easy
    # re-establishing of the connection.
    def self.remove_connection(klass=self)
      conn = @@defined_connections[klass]
      @@defined_connections.delete(klass)
      active_connections[klass] = nil
      conn.config if conn
    end

    # Set the connection for the class.
    def self.connection=(spec)
      raise ConnectionNotEstablished unless spec
      conn = self.send(spec.adapter_method, spec.config)
      active_connections[self] = conn
    end

    # Converts all strings in a hash to symbols.
    def self.symbolize_strings_in_hash(hash) #:nodoc:
      hash.symbolize_keys
    end
  end

  module ConnectionAdapters # :nodoc:
    class Column # :nodoc:
      attr_reader :name, :default, :type, :limit
      # The name should contain the name of the column, such as "name" in "name varchar(250)"
      # The default should contain the type-casted default of the column, such as 1 in "count int(11) DEFAULT 1"
      # The type parameter should either contain :integer, :float, :datetime, :date, :text, or :string
      # The sql_type is just used for extracting the limit, such as 10 in "varchar(10)"
      def initialize(name, default, sql_type = nil)
        @name, @default, @type = name, type_cast(default), simplified_type(sql_type)
        @limit = extract_limit(sql_type) unless sql_type.nil?
      end

      def klass
        case type
          when :integer       then Fixnum
          when :float         then Float
          when :datetime      then Time
          when :date          then Date
          when :timestamp     then Time
          when :time          then Time
          when :text, :string then String
          when :binary        then String
          when :boolean       then Object
        end
      end

      def type_cast(value)
        if value.nil? then return nil end
        case type
          when :string    then value
          when :text      then value
          when :integer   then value.to_i rescue value ? 1 : 0
          when :float     then value.to_f
          when :datetime  then string_to_time(value)
          when :timestamp then string_to_time(value)
          when :time      then string_to_dummy_time(value)
          when :date      then string_to_date(value)
          when :binary    then binary_to_string(value)
          when :boolean   then value == true or (value =~ /^t(rue)?$/i) == 0 or value.to_s == '1'
          else value
        end
      end

      def human_name
        Base.human_attribute_name(@name)
      end

      def string_to_binary(value)
        value
      end

      def binary_to_string(value)
        value
      end

      private
        def string_to_date(string)
          return string unless string.is_a?(String)
          date_array = ParseDate.parsedate(string.to_s)
          # treat 0000-00-00 as nil
          Date.new(date_array[0], date_array[1], date_array[2]) rescue nil
        end

        def string_to_time(string)
          return string unless string.is_a?(String)
          time_array = ParseDate.parsedate(string.to_s).compact
          # treat 0000-00-00 00:00:00 as nil
          Time.send(Base.default_timezone, *time_array) rescue nil
        end

        def string_to_dummy_time(string)
          return string unless string.is_a?(String)
          time_array = ParseDate.parsedate(string.to_s)
          # pad the resulting array with dummy date information
          time_array[0] = 2000; time_array[1] = 1; time_array[2] = 1;
          Time.send(Base.default_timezone, *time_array) rescue nil
        end

        def extract_limit(sql_type)
          $1.to_i if sql_type =~ /\((.*)\)/
        end

        def simplified_type(field_type)
          case field_type
            when /int/i
              :integer
            when /float|double|decimal|numeric/i
              :float
            when /datetime/i
              :datetime
            when /timestamp/i
              :timestamp
            when /time/i
              :time
            when /date/i
              :date
            when /clob/i, /text/i
              :text
            when /blob/i, /binary/i
              :binary
            when /char/i, /string/i
              :string
            when /boolean/i
              :boolean
          end
        end
    end

    # All the concrete database adapters follow the interface laid down in this class.
    # You can use this interface directly by borrowing the database connection from the Base with
    # Base.connection.
    class AbstractAdapter
      @@row_even = true

      def initialize(connection, logger = nil) # :nodoc:
        @connection, @logger = connection, logger
        @runtime = 0
      end

      # Returns an array of record hashes with the column names as a keys and fields as values.
      def select_all(sql, name = nil) end

      # Returns a record hash with the column names as a keys and fields as values.
      def select_one(sql, name = nil) end

      # Returns an array of column objects for the table specified by +table_name+.
      def columns(table_name, name = nil) end

      # Returns the last auto-generated ID from the affected table.
      def insert(sql, name = nil, pk = nil, id_value = nil) end

      # Executes the update statement and returns the number of rows affected.
      def update(sql, name = nil) end

      # Executes the delete statement and returns the number of rows affected.
      def delete(sql, name = nil) end

      def reset_runtime # :nodoc:
        rt = @runtime
        @runtime = 0
        return rt
      end

      # Wrap a block in a transaction.  Returns result of block.
      def transaction(start_db_transaction = true)
        begin
          if block_given?
            begin_db_transaction if start_db_transaction
            result = yield
            commit_db_transaction if start_db_transaction
            result
          end
        rescue Exception => database_transaction_rollback
          rollback_db_transaction if start_db_transaction
          raise
        end
      end

      # Begins the transaction (and turns off auto-committing).
      def begin_db_transaction()    end

      # Commits the transaction (and turns on auto-committing).
      def commit_db_transaction()   end

      # Rolls back the transaction (and turns on auto-committing). Must be done if the transaction block
      # raises an exception or returns false.
      def rollback_db_transaction() end

      def quote(value, column = nil)
        case value
          when String
            if column && column.type == :binary
              "'#{quote_string(column.string_to_binary(value))}'" # ' (for ruby-mode)
            else
              "'#{quote_string(value)}'" # ' (for ruby-mode)
            end
          when NilClass              then "NULL"
          when TrueClass             then (column && column.type == :boolean ? "'t'" : "1")
          when FalseClass            then (column && column.type == :boolean ? "'f'" : "0")
          when Float, Fixnum, Bignum then value.to_s
          when Date                  then "'#{value.to_s}'"
          when Time, DateTime        then "'#{value.strftime("%Y-%m-%d %H:%M:%S")}'"
          else                            "'#{quote_string(value.to_yaml)}'"
        end
      end

      def quote_string(s)
        s.gsub(/\\/, '\&\&').gsub(/'/, "''") # ' (for ruby-mode)
      end

      def quote_column_name(name)
        name
      end

      # Returns the human-readable name of the adapter.  Use mixed case - one can always use downcase if needed.
      def adapter_name()
        'Abstract'
      end

      # Returns a string of the CREATE TABLE SQL statements for recreating the entire structure of the database.
      def structure_dump() end

      def add_limit!(sql, options)
        return unless options
        add_limit_offset!(sql, options)
      end

      def add_limit_offset!(sql, options)
        return if options[:limit].nil?
        sql << " LIMIT #{options[:limit]}"
        sql << " OFFSET #{options[:offset]}" if options.has_key?(:offset) and !options[:offset].nil?
      end


      def initialize_schema_information
        begin
          execute "CREATE TABLE schema_info (version #{type_to_sql(:integer)})"
          execute "INSERT INTO schema_info (version) VALUES(0)"
        rescue ActiveRecord::StatementInvalid
          # Schema has been intialized
        end
      end
      
      def create_table(name, options = {})
        table_definition = TableDefinition.new(self)
        table_definition.primary_key(options[:primary_key] || "id") unless options[:id] == false

        yield table_definition
        create_sql = "CREATE TABLE #{name} ("
        create_sql << table_definition.to_sql
        create_sql << ") #{options[:options]}"
                
        execute create_sql
      end

      def drop_table(name)
        execute "DROP TABLE #{name}"
      end

      def add_column(table_name, column_name, type, options = {})
        native_type = native_database_types[type]
        add_column_sql = "ALTER TABLE #{table_name} ADD #{column_name} #{type_to_sql(type, options[:limit])}"
        add_column_options!(add_column_sql, options)
        execute(add_column_sql)
      end
      
      def remove_column(table_name, column_name)
        execute "ALTER TABLE #{table_name} DROP #{column_name}"
      end      

      def change_column(table_name, column_name, type, options = {})
        raise NotImplementedError, "change_column is not implemented"
      end
      
      def change_column_default(table_name, column_name, default)
        raise NotImplementedError, "change_column_default is not implemented"
      end
      
      def supports_migrations?
        false
      end      

      def rename_column(table_name, column_name, new_column_name)
        raise NotImplementedError, "rename_column is not implemented"
      end

      def add_index(table_name, column_name, index_type = '')
        execute "CREATE #{index_type} INDEX #{table_name}_#{column_name.to_a.first}_index ON #{table_name} (#{column_name.to_a.join(", ")})"
      end

      def remove_index(table_name, column_name)
        execute "DROP INDEX #{table_name}_#{column_name}_index ON #{table_name}"
      end
      
      def supports_migrations?
        false
      end           

      def native_database_types
        {}
      end       

      def type_to_sql(type, limit = nil)
        native = native_database_types[type]
        limit ||= native[:limit]
        column_type_sql = native[:name]
        column_type_sql << "(#{limit})" if limit
        column_type_sql
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
      
        def add_column_options!(sql, options)
          sql << " DEFAULT '#{options[:default]}'" unless options[:default].nil?
        end
    end

    class TableDefinition
      attr_accessor :columns

      def initialize(base)
        @columns = []
        @base = base
      end

      def primary_key(name)
        @columns << "#{name} #{native[:primary_key]}"
        self
      end

      def column(name, type, options = {})
        limit = options[:limit] || native[type.to_sym][:limit]
        
        column_sql = "#{name} #{type_to_sql(type.to_sym, options[:limit])}"
        column_sql << " DEFAULT '#{options[:default]}'" if options[:default]
        @columns << column_sql
        self
      end
      
      def to_sql
        @columns.join(", ")
      end
      
      private
      
      def type_to_sql(name, limit)
        @base.type_to_sql(name, limit)
      end
      
      def native
        @base.native_database_types
      end
    end
  end
end
