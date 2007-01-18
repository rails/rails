# Requires FrontBase Ruby bindings (gem install ruby-frontbase)

require 'active_record/connection_adapters/abstract_adapter'

FB_TRACE = false

module ActiveRecord

  class Base
    class << self
      # Establishes a connection to the database that's used by all Active Record objects.
      def frontbase_connection(config) # :nodoc:
        # FrontBase only supports one unnamed sequence per table
        define_attr_method(:set_sequence_name, :sequence_name, &Proc.new {|*args| nil})

        config = config.symbolize_keys
        database     = config[:database]
        port         = config[:port]
        host         = config[:host]
        username     = config[:username]
        password     = config[:password]
        dbpassword   = config[:dbpassword]
        session_name = config[:session_name]

        dbpassword = '' if dbpassword.nil?
        
        # Turn off colorization since it makes tail/less output difficult
        self.colorize_logging = false

        require_library_or_gem 'frontbase' unless self.class.const_defined? :FBSQL_Connect
        
        # Check bindings version
        version = "0.0.0"
        version = FBSQL_Connect::FB_BINDINGS_VERSION if defined? FBSQL_Connect::FB_BINDINGS_VERSION
        
        if ActiveRecord::ConnectionAdapters::FrontBaseAdapter.compare_versions(version,"1.0.0") == -1
          raise AdapterNotFound,
            'The FrontBase adapter requires ruby-frontbase version 1.0.0 or greater; you appear ' <<
            "to be running an older version (#{version}) -- please update ruby-frontbase (gem install ruby-frontbase)."
        end
        connection = FBSQL_Connect.connect(host, port, database, username, password, dbpassword, session_name)
        ConnectionAdapters::FrontBaseAdapter.new(connection, logger, [host, port, database, username, password, dbpassword, session_name], config)
      end            
    end    
  end
  
  module ConnectionAdapters
    
    # From EOF Documentation....
    # buffer should have space for EOUniqueBinaryKeyLength (12) bytes.
    # Assigns a world-wide unique ID made up of:
    # < Sequence [2], ProcessID [2] , Time [4], IP Addr [4] >
    
    class TwelveByteKey < String #:nodoc:
      @@mutex = Mutex.new
      @@sequence_number = rand(65536)
      @@key_cached_pid_component = nil
      @@key_cached_ip_component = nil

      def initialize(string = nil)
        # Generate a unique key
        if string.nil?
          new_key = replace('_' * 12)

          new_key[0..1]  = self.class.key_sequence_component        
          new_key[2..3]  = self.class.key_pid_component
          new_key[4..7]  = self.class.key_time_component
          new_key[8..11] = self.class.key_ip_component
          new_key
        else
          if string.size == 24
            string.gsub!(/[[:xdigit:]]{2}/) { |x| x.hex.chr }
          end
          raise "string is not 12 bytes long" unless string.size == 12
          super(string)
        end
      end
            
      def inspect
        unpack("H*").first.upcase
      end
    
      alias_method :to_s, :inspect
      
      private
            
        class << self
          def key_sequence_component
            seq = nil
            @@mutex.synchronize do
              seq = @@sequence_number
              @@sequence_number = (@@sequence_number + 1) % 65536
            end
            
            sequence_component = "__"
            sequence_component[0] = seq >> 8
            sequence_component[1] = seq
            sequence_component
          end
          
          def key_pid_component
            if @@key_cached_pid_component.nil?
              @@mutex.synchronize do
                pid = $$
                pid_component = "__"
                pid_component[0] = pid >> 8
                pid_component[1] = pid
                @@key_cached_pid_component = pid_component
              end
            end
            @@key_cached_pid_component
          end
          
          def key_time_component
            time = Time.new.to_i
            time_component = "____"
            time_component[0] = (time & 0xFF000000) >> 24
            time_component[1] = (time & 0x00FF0000) >> 16
            time_component[2] = (time & 0x0000FF00) >> 8
            time_component[3] = (time & 0x000000FF)
            time_component
          end
          
          def key_ip_component
            if @@key_cached_ip_component.nil?
              @@mutex.synchronize do
                old_lookup_flag  = BasicSocket.do_not_reverse_lookup
                BasicSocket.do_not_reverse_lookup = true
                udpsocket = UDPSocket.new
                udpsocket.connect("17.112.152.32",1)
                ip_string = udpsocket.addr[3]
                BasicSocket.do_not_reverse_lookup = old_lookup_flag
                packed = Socket.pack_sockaddr_in(0,ip_string)
                addr_subset = packed[4..7]
                ip = addr_subset[0] << 24 | addr_subset[1] << 16 | addr_subset[2] << 8 | addr_subset[3]
                ip_component = "____"
                ip_component[0] = (ip & 0xFF000000) >> 24
                ip_component[1] = (ip & 0x00FF0000) >> 16
                ip_component[2] = (ip & 0x0000FF00) >> 8
                ip_component[3] = (ip & 0x000000FF)
                @@key_cached_ip_component = ip_component
              end
            end
            @@key_cached_ip_component
          end
        end
    end
    
    class FrontBaseColumn < Column #:nodoc:
      attr_reader :fb_autogen
      
      def initialize(base, name, type, typename, limit, precision, scale, default, nullable)
        
        @base       = base
        @name       = name
        @type       = simplified_type(type,typename,limit)
        @limit      = limit
        @precision  = precision
        @scale      = scale
        @default    = default
        @null       = nullable == "YES"
        @text       = [:string, :text].include? @type
        @number     = [:float, :integer, :decimal].include? @type
        @fb_autogen = false

        if @default
          @default.gsub!(/^'(.*)'$/,'\1') if @text
          @fb_autogen =  @default.include?("SELECT UNIQUE FROM")
          case @type
          when :boolean 
            @default = @default == "TRUE"
          when :binary
            if @default != "X''"
              buffer = ""
              @default.scan(/../) { |h| buffer << h.hex.chr }
              @default = buffer
            else
              @default = ""
            end
          else
            @default = type_cast(@default)
          end
        end
      end
      
      # Casts value (which is a String) to an appropriate instance.
      def type_cast(value)
        if type == :twelvebytekey
          ActiveRecord::ConnectionAdapters::TwelveByteKey.new(value)
        else
          super(value)
        end
      end

      def type_cast_code(var_name)
        if type == :twelvebytekey
          "ActiveRecord::ConnectionAdapters::TwelveByteKey.new(#{var_name})"
        else
          super(var_name)
        end
      end

      private
        def simplified_type(field_type, type_name,limit)
          ret_type = :string
          puts "typecode: [#{field_type}] [#{type_name}]"  if FB_TRACE

          # 12 byte primary keys are a special case that Apple's EOF
          # used heavily.  Optimize for this case
          if field_type == 11 && limit == 96
           ret_type = :twelvebytekey            # BIT(96)
          else
           ret_type = case field_type
             when 1  then :boolean   # BOOLEAN
             when 2  then :integer   # INTEGER
             when 4  then :float     # FLOAT
             when 10 then :string    # CHARACTER VARYING
             when 11 then :bitfield  # BIT
             when 13 then :date      # DATE
             when 14 then :time      # TIME
             when 16 then :timestamp # TIMESTAMP
             when 20 then :text      # CLOB
             when 21 then :binary    # BLOB
             when 22 then :integer   # TINYINT
             else
               puts "ERROR: Unknown typecode: [#{field_type}] [#{type_name}]"
           end
          end
          puts "ret_type: #{ret_type.inspect}" if FB_TRACE
          ret_type
        end
    end

    class FrontBaseAdapter < AbstractAdapter
        
      class << self
        def compare_versions(v1, v2)
          v1_seg  = v1.split(".")
          v2_seg  = v2.split(".")
          0.upto([v1_seg.length,v2_seg.length].min) do |i|
            step  = (v1_seg[i].to_i <=> v2_seg[i].to_i)
            return step unless step == 0
          end
          return v1_seg.length <=> v2_seg.length
        end    
      end
            
      def initialize(connection, logger, connection_options, config)
        super(connection, logger)
        @connection_options, @config = connection_options, config
        @transaction_mode = :pessimistic
        
        # Start out in auto-commit mode
        self.rollback_db_transaction
        
        # threaded_connections_test.rb will fail unless we set the session
        # to optimistic locking mode
#         set_pessimistic_transactions
#         execute "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ WRITE, LOCKING OPTIMISTIC"
      end

      # Returns the human-readable name of the adapter.  Use mixed case - one
      # can always use downcase if needed.
      def adapter_name #:nodoc:
        'FrontBase'
      end

      # Does this adapter support migrations?  Backend specific, as the
      # abstract adapter always returns +false+.
      def supports_migrations? #:nodoc:
        true
      end

      def native_database_types #:nodoc:
        {
          :primary_key    => "INTEGER DEFAULT UNIQUE PRIMARY KEY",
          :string         => { :name => "VARCHAR", :limit => 255 },
          :text           => { :name => "CLOB" },
          :integer        => { :name => "INTEGER" },
          :float          => { :name => "FLOAT" },
          :decimal        => { :name => "DECIMAL" },
          :datetime       => { :name => "TIMESTAMP" },
          :timestamp      => { :name => "TIMESTAMP" },
          :time           => { :name => "TIME" },
          :date           => { :name => "DATE" },
          :binary         => { :name => "BLOB" },
          :boolean        => { :name => "BOOLEAN" },
          :twelvebytekey  => { :name => "BYTE", :limit => 12}
        }
      end


      # QUOTING ==================================================

      # Quotes the column value to help prevent
      # {SQL injection attacks}[http://en.wikipedia.org/wiki/SQL_injection].
      def quote(value, column = nil)
        return value.quoted_id if value.respond_to?(:quoted_id)

        retvalue = "<INVALID>"

        puts "quote(#{value.inspect}(#{value.class}),#{column.type.inspect})" if FB_TRACE
        # If a column was passed in, use column type information
        unless value.nil?
          if column
            retvalue = case column.type
              when :string
                if value.kind_of?(String)
                  "'#{quote_string(value.to_s)}'" # ' (for ruby-mode)
                else
                  "'#{quote_string(value.to_yaml)}'"
                end
              when :integer
                if value.kind_of?(TrueClass)
                  '1'
                elsif value.kind_of?(FalseClass)
                  '0'
                else
                   value.to_i.to_s
                end
              when :float
                value.to_f.to_s
              when :decimal
                value.to_d.to_s("F")
              when :datetime, :timestamp
                "TIMESTAMP '#{value.strftime("%Y-%m-%d %H:%M:%S")}'"
              when :time
                "TIME '#{value.strftime("%H:%M:%S")}'"
              when :date
                "DATE '#{value.strftime("%Y-%m-%d")}'"
              when :twelvebytekey
                value = value.to_s.unpack("H*").first unless value.kind_of?(TwelveByteKey)
                "X'#{value.to_s}'"
              when :boolean
                value = quoted_true if value.kind_of?(TrueClass)
                value = quoted_false if value.kind_of?(FalseClass)
                value
              when :binary
                blob_handle = @connection.create_blob(value.to_s)
                puts "SQL -> Insert #{value.to_s.length} byte blob as #{retvalue}" if FB_TRACE
                blob_handle.handle
              when :text
                if value.kind_of?(String)
                  clobdata = value.to_s # ' (for ruby-mode)
                else
                  clobdata = value.to_yaml
                end
                clob_handle = @connection.create_clob(clobdata)
                puts "SQL -> Insert #{value.to_s.length} byte clob as #{retvalue}" if FB_TRACE
                clob_handle.handle
              else
                raise "*** UNKNOWN TYPE: #{column.type.inspect}"
            end # case
          # Since we don't have column type info, make a best guess based
          # on the Ruby class of the value
          else
            retvalue = case value
              when ActiveRecord::ConnectionAdapters::TwelveByteKey
                s = value.unpack("H*").first
                "X'#{s}'"
              when String
                if column && column.type == :binary
                  s = value.unpack("H*").first
                  "X'#{s}'"
                elsif column && [:integer, :float, :decimal].include?(column.type) 
                  value.to_s
                else
                  "'#{quote_string(value)}'" # ' (for ruby-mode)
                end
              when NilClass
                "NULL"
              when TrueClass
                (column && column.type == :integer ? '1' : quoted_true)
              when FalseClass
                (column && column.type == :integer ? '0' : quoted_false)
              when Float, Fixnum, Bignum, BigDecimal
                value.to_s
              when Time, Date, DateTime
                if column
                  case column.type
                    when :date
                      "DATE '#{value.strftime("%Y-%m-%d")}'"
                    when :time
                      "TIME '#{value.strftime("%H:%M:%S")}'"
                    when :timestamp
                      "TIMESTAMP '#{value.strftime("%Y-%m-%d %H:%M:%S")}'"
                  else
                    raise NotImplementedError, "Unknown column type!"
                  end # case
                else # Column wasn't passed in, so try to guess the right type
                  if value.kind_of? Date
                    "DATE '#{value.strftime("%Y-%m-%d")}'"
                  else
                    if [:hour, :min, :sec].all? {|part| value.send(:part).zero? }
                      "TIME '#{value.strftime("%H:%M:%S")}'"
                    else
                      "TIMESTAMP '#{quoted_date(value)}'"
                    end
                  end 
                end #if column
              else 
                "'#{quote_string(value.to_yaml)}'"
            end #case
          end
        else
          retvalue = "NULL"
        end
         
        retvalue
      end # def

      # Quotes a string, escaping any ' (single quote) characters.
      def quote_string(s)
        s.gsub(/'/, "''") # ' (for ruby-mode)
      end

      def quote_column_name(name) #:nodoc:
        %( "#{name}" )
      end

      def quoted_true
        "true"
      end
      
      def quoted_false
        "false"
      end


      # CONNECTION MANAGEMENT ====================================

      def active?
        true if @connection.status == 1
      rescue => e
        false
      end

      def reconnect!
        @connection.close rescue nil
        @connection = FBSQL_Connect.connect(*@connection_options.first(7))
      end

      # Close this connection
      def disconnect!
        @connection.close rescue nil
        @active = false
      end

      # DATABASE STATEMENTS ======================================

      # Returns an array of record hashes with the column names as keys and
      # column values as values.
      def select_all(sql, name = nil) #:nodoc:
        fbsql        = cleanup_fb_sql(sql)
        return_value = []
        fbresult     = execute(sql, name)
        puts "select_all SQL -> #{fbsql}" if FB_TRACE
        columns = fbresult.columns

        fbresult.each do |row|
          puts "SQL <- #{row.inspect}"  if FB_TRACE
          hashed_row = {}    
          colnum     = 0
          row.each do |col|
            hashed_row[columns[colnum]] = col
            if col.kind_of?(FBSQL_LOB)
              hashed_row[columns[colnum]] = col.read
            end
            colnum += 1
          end
          puts "raw row: #{hashed_row.inspect}" if FB_TRACE
          return_value << hashed_row
        end
        return_value
      end

      def select_one(sql, name = nil) #:nodoc:
        fbsql        = cleanup_fb_sql(sql)
        return_value = []
        fbresult     = execute(fbsql, name)
        puts "SQL -> #{fbsql}"  if FB_TRACE
        columns = fbresult.columns
        
        fbresult.each do |row|
          puts "SQL <- #{row.inspect}"  if FB_TRACE
          hashed_row = {}    
          colnum     = 0
          row.each do |col|
            hashed_row[columns[colnum]] = col
            if col.kind_of?(FBSQL_LOB)
              hashed_row[columns[colnum]] = col.read
            end
            colnum += 1
          end
          return_value << hashed_row
          break
        end
        fbresult.clear
        return_value.first
      end

      def query(sql, name = nil) #:nodoc:
        fbsql = cleanup_fb_sql(sql)
        puts "SQL(query) -> #{fbsql}"  if FB_TRACE
        log(fbsql, name) { @connection.query(fbsql) }
      rescue => e
        puts "FB Exception: #{e.inspect}" if FB_TRACE
        raise e
      end

      def execute(sql, name = nil) #:nodoc:
        fbsql = cleanup_fb_sql(sql)
        puts "SQL(execute) -> #{fbsql}"  if FB_TRACE
        log(fbsql, name) { @connection.query(fbsql) }
      rescue ActiveRecord::StatementInvalid => e
        if e.message.scan(/Table name - \w* - exists/).empty?
          puts "FB Exception: #{e.inspect}" if FB_TRACE
          raise e
        end
      end
      
      # Returns the last auto-generated ID from the affected table.
      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        puts "SQL -> #{sql.inspect}"  if FB_TRACE
        execute(sql, name)
        id_value || pk
      end

      # Executes the update statement and returns the number of rows affected.
      def update(sql, name = nil) #:nodoc:
        puts "SQL -> #{sql.inspect}"  if FB_TRACE
        execute(sql, name).num_rows
      end

      alias_method :delete, :update #:nodoc:

      def set_pessimistic_transactions
        if @transaction_mode == :optimistic
          execute "SET TRANSACTION ISOLATION LEVEL SERIALIZABLE, LOCKING PESSIMISTIC, READ WRITE"
          @transaction_mode = :pessimistic
        end
      end

      def set_optimistic_transactions
        if @transaction_mode == :pessimistic
          execute "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ WRITE, LOCKING OPTIMISTIC"
          @transaction_mode = :optimistic
        end
      end

      def begin_db_transaction #:nodoc:
        execute "SET COMMIT FALSE" rescue nil
      end

      def commit_db_transaction #:nodoc:
        execute "COMMIT"
      ensure
        execute "SET COMMIT TRUE"
      end

      def rollback_db_transaction #:nodoc:
        execute "ROLLBACK"
      ensure
        execute "SET COMMIT TRUE"
      end

      def add_limit_offset!(sql, options) #:nodoc:
        if limit = options[:limit]
          offset = options[:offset] || 0
        
# Here is the full syntax FrontBase supports:
# (from gclem@frontbase.com)
# 
#       TOP <limit - unsigned integer>
#       TOP ( <offset expr>, <limit expr>)
        
          # "TOP 0" is not allowed, so we have
          # to use a cheap trick.
          if limit.zero?
            case sql
            when /WHERE/i
              sql.sub!(/WHERE/i, 'WHERE 0 = 1 AND ')
            when /ORDER\s+BY/i
              sql.sub!(/ORDER\s+BY/i, 'WHERE 0 = 1 ORDER BY')
            else
              sql << 'WHERE 0 = 1'
            end
          else
            if offset.zero?
              sql.replace sql.gsub("SELECT ","SELECT TOP #{limit} ")
            else
              sql.replace sql.gsub("SELECT ","SELECT TOP(#{offset},#{limit}) ")
            end
          end
        end
      end

      def prefetch_primary_key?(table_name = nil)
        true
      end

      # Returns the next sequence value from a sequence generator. Not generally
      # called directly; used by ActiveRecord to get the next primary key value
      # when inserting a new database record (see #prefetch_primary_key?).
      def next_sequence_value(sequence_name)
        unique = select_value("SELECT UNIQUE FROM #{sequence_name}","Next Sequence Value")
        # The test cases cannot handle a zero primary key
        unique.zero? ? select_value("SELECT UNIQUE FROM #{sequence_name}","Next Sequence Value") : unique
      end

      def default_sequence_name(table, column)
        table
      end

      # Set the sequence to the max value of the table's column.
      def reset_sequence!(table, column, sequence = nil)
        klasses = classes_for_table_name(table)
        klass   = klasses.nil? ? nil : klasses.first
        pk      = klass.primary_key unless klass.nil?
        if pk && klass.columns_hash[pk].type == :integer
          execute("SET UNIQUE FOR #{klass.table_name}(#{pk})")
        end
      end

      def classes_for_table_name(table)
        ActiveRecord::Base.send(:subclasses).select {|klass| klass.table_name == table}
      end
      
      def reset_pk_sequence!(table, pk = nil, sequence = nil)
        klasses = classes_for_table_name(table)
        klass   = klasses.nil? ? nil : klasses.first
        pk      = klass.primary_key unless klass.nil?
        if pk && klass.columns_hash[pk].type == :integer
          mpk = select_value("SELECT MAX(#{pk}) FROM #{table}")
          execute("SET UNIQUE FOR #{klass.table_name}(#{pk})")
        end
      end

      # SCHEMA STATEMENTS ========================================

      def structure_dump #:nodoc:
        select_all("SHOW TABLES").inject('') do |structure, table|
          structure << select_one("SHOW CREATE TABLE #{table.to_a.first.last}")["Create Table"] << ";\n\n"
        end
      end

      def recreate_database(name) #:nodoc:
        drop_database(name)
        create_database(name)
      end

      def create_database(name) #:nodoc:
        execute "CREATE DATABASE #{name}"
      end
      
      def drop_database(name) #:nodoc:
        execute "DROP DATABASE #{name}"
      end

      def current_database
        select_value('SELECT "CATALOG_NAME" FROM INFORMATION_SCHEMA.CATALOGS').downcase
      end

      def tables(name = nil) #:nodoc:
        select_values(<<-SQL, nil)
          SELECT "TABLE_NAME" 
          FROM   INFORMATION_SCHEMA.TABLES   AS T0,
                 INFORMATION_SCHEMA.SCHEMATA AS T1 
          WHERE  T0.SCHEMA_PK  = T1.SCHEMA_PK 
          AND    "SCHEMA_NAME" = CURRENT_SCHEMA
        SQL
      end

      def indexes(table_name, name = nil)#:nodoc:
        indexes = []
        current_index = nil
        sql = <<-SQL
          SELECT   INDEX_NAME, T2.ORDINAL_POSITION, INDEX_COLUMN_COUNT, INDEX_TYPE, 
                   "COLUMN_NAME", IS_NULLABLE 
          FROM     INFORMATION_SCHEMA.TABLES             AS T0, 
                   INFORMATION_SCHEMA.INDEXES            AS T1, 
                   INFORMATION_SCHEMA.INDEX_COLUMN_USAGE AS T2, 
                   INFORMATION_SCHEMA.COLUMNS            AS T3 
          WHERE    T0."TABLE_NAME" = '#{table_name}' 
            AND    INDEX_TYPE <> 0 
            AND    T0.TABLE_PK   = T1.TABLE_PK 
            AND    T0.TABLE_PK   = T2.TABLE_PK 
            AND    T0.TABLE_PK   = T3.TABLE_PK 
            AND    T1.INDEXES_PK = T2.INDEX_PK 
            AND    T2.COLUMN_PK  = T3.COLUMN_PK 
          ORDER BY INDEX_NAME, T2.ORDINAL_POSITION
        SQL

        columns = []
        query(sql).each do |row|
          index_name   = row[0]
          ord_position = row[1]
          ndx_colcount = row[2]
          index_type   = row[3]
          column_name  = row[4]
          
          is_unique = index_type == 1
          
          columns << column_name
          if ord_position == ndx_colcount
            indexes << IndexDefinition.new(table_name, index_name, is_unique , columns)
            columns = []
          end
        end
        indexes
      end

      def columns(table_name, name = nil)#:nodoc:
        sql = <<-SQL
          SELECT   "TABLE_NAME", "COLUMN_NAME", ORDINAL_POSITION, IS_NULLABLE, COLUMN_DEFAULT, 
                   DATA_TYPE, DATA_TYPE_CODE, CHARACTER_MAXIMUM_LENGTH, NUMERIC_PRECISION, 
                   NUMERIC_PRECISION_RADIX, NUMERIC_SCALE, DATETIME_PRECISION, DATETIME_PRECISION_LEADING 
          FROM     INFORMATION_SCHEMA.TABLES               T0, 
                   INFORMATION_SCHEMA.COLUMNS              T1, 
                   INFORMATION_SCHEMA.DATA_TYPE_DESCRIPTOR T3 
          WHERE    "TABLE_NAME" = '#{table_name}' 
            AND    T0.TABLE_PK  = T1.TABLE_PK 
            AND    T0.TABLE_PK  = T3.TABLE_OR_DOMAIN_PK 
            AND    T1.COLUMN_PK = T3.COLUMN_NAME_PK 
          ORDER BY T1.ORDINAL_POSITION
        SQL

        rawresults = query(sql,name)
        columns = []
        rawresults.each do |field|
          args = [base       = field[0],
                  name       = field[1],
                  typecode   = field[6],
                  typestring = field[5],
                  limit      = field[7],
                  precision  = field[8],
                  scale      = field[9],
                  default    = field[4],
                  nullable   = field[3]]
          columns << FrontBaseColumn.new(*args)
         end
        columns
      end
      
      def create_table(name, options = {})
        table_definition = TableDefinition.new(self)
        table_definition.primary_key(options[:primary_key] || "id") unless options[:id] == false

        yield table_definition

        if options[:force]
          drop_table(name) rescue nil
        end

        create_sql = "CREATE#{' TEMPORARY' if options[:temporary]} TABLE "
        create_sql << "#{name} ("
        create_sql << table_definition.to_sql
        create_sql << ") #{options[:options]}"
        begin_db_transaction
        execute create_sql
        commit_db_transaction
        rescue ActiveRecord::StatementInvalid => e
          raise e unless e.message.match(/Table name - \w* - exists/)
      end
      
      def rename_table(name, new_name)
        columns = columns(name)
        pkcol = columns.find {|c| c.fb_autogen}
        execute "ALTER TABLE NAME #{name} TO #{new_name}"
        if pkcol
          change_column_default(new_name,pkcol.name,"UNIQUE")
          begin_db_transaction
          mpk = select_value("SELECT MAX(#{pkcol.name}) FROM #{new_name}")
          mpk = 0 if mpk.nil?
          execute "SET UNIQUE=#{mpk} FOR #{new_name}"
          commit_db_transaction
        end
      end  

      # Drops a table from the database.
      def drop_table(name, options = {})
        execute "DROP TABLE #{name} RESTRICT"
      rescue ActiveRecord::StatementInvalid => e
        raise e unless e.message.match(/Referenced TABLE - \w* - does not exist/)
      end

      # Adds a new column to the named table.
      # See TableDefinition#column for details of the options you can use.
      def add_column(table_name, column_name, type, options = {})
        add_column_sql = "ALTER TABLE #{table_name} ADD #{column_name} #{type_to_sql(type, options[:limit])}"
        options[:type] = type
        add_column_options!(add_column_sql, options)
        execute(add_column_sql)
      end

      def add_column_options!(sql, options) #:nodoc:
        default_value = quote(options[:default], options[:column])
        if options_include_default?(options)
          if options[:type] == :boolean
            default_value = options[:default] == 0 ? quoted_false : quoted_true
          end
          sql << " DEFAULT #{default_value}"
        end
        sql << " NOT NULL" if options[:null] == false
      end

      # Removes the column from the table definition.
      # ===== Examples
      #  remove_column(:suppliers, :qualification)
      def remove_column(table_name, column_name)
        execute "ALTER TABLE #{table_name} DROP #{column_name} RESTRICT"
      end

      def remove_index(table_name, options = {}) #:nodoc:
        if options[:unique]
          execute "ALTER TABLE #{table_name} DROP CONSTRAINT #{quote_column_name(index_name(table_name, options))} RESTRICT"
        else
          execute "DROP INDEX #{quote_column_name(index_name(table_name, options))}"
        end
      end

      def change_column_default(table_name, column_name, default) #:nodoc:
        execute "ALTER TABLE #{table_name} ALTER COLUMN #{column_name} SET DEFAULT #{default}" if default != "NULL"
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        change_column_sql = %( ALTER COLUMN "#{table_name}"."#{column_name}" TO #{type_to_sql(type, options[:limit])} )
        execute(change_column_sql)
        change_column_sql = %( ALTER TABLE "#{table_name}" ALTER COLUMN "#{column_name}" )

        if options_include_default?(options)
          default_value = quote(options[:default], options[:column])
          if type == :boolean
            default_value = options[:default] == 0 ? quoted_false : quoted_true
          end
          change_column_sql << " SET DEFAULT #{default_value}"
        end

        execute(change_column_sql)
        
#         change_column_sql = "ALTER TABLE #{table_name} CHANGE #{column_name} #{column_name} #{type_to_sql(type, options[:limit])}"
#         add_column_options!(change_column_sql, options)
#         execute(change_column_sql)
      end

      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        execute %( ALTER COLUMN NAME "#{table_name}"."#{column_name}" TO "#{new_column_name}" )
      end
            
      private
      
        # Clean up sql to make it something FrontBase can digest
        def cleanup_fb_sql(sql) #:nodoc:
          # Turn non-standard != into standard <>
          cleansql = sql.gsub("!=", "<>") 
          # Strip blank lines and comments
          cleansql.split("\n").reject { |line| line.match(/^(?:\s*|--.*)$/) } * "\n"
        end
    end
  end
end
