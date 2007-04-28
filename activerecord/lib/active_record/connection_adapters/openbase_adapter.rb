require 'active_record/connection_adapters/abstract_adapter'

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects
    def self.openbase_connection(config) # :nodoc:
      require_library_or_gem 'openbase' unless self.class.const_defined?(:OpenBase)

      config = config.symbolize_keys
      host     = config[:host]
      username = config[:username].to_s
      password = config[:password].to_s
      

      if config.has_key?(:database)
        database = config[:database]
      else
        raise ArgumentError, "No database specified. Missing argument: database."
      end

      oba = ConnectionAdapters::OpenBaseAdapter.new(
        OpenBase.new(database, host, username, password), logger
      )
      
      oba
    end
    
  end

  module ConnectionAdapters
    class OpenBaseColumn < Column #:nodoc:
      private
        def simplified_type(field_type)
          return :integer if field_type.downcase =~ /long/
          return :decimal if field_type.downcase == "money"
          return :binary  if field_type.downcase == "object"
          super
        end
    end
    # The OpenBase adapter works with the Ruby/Openbase driver by Tetsuya Suzuki.
    # http://www.spice-of-life.net/ruby-openbase/ (needs version 0.7.3+)
    #
    # Options:
    #
    # * <tt>:host</tt> -- Defaults to localhost
    # * <tt>:username</tt> -- Defaults to nothing
    # * <tt>:password</tt> -- Defaults to nothing
    # * <tt>:database</tt> -- The name of the database. No default, must be provided.
    #
    # The OpenBase adapter will make use of OpenBase's ability to generate unique ids
    # for any column with an unique index applied.  Thus, if the value of a primary
    # key is not specified at the time an INSERT is performed, the adapter will prefetch
    # a unique id for the primary key.  This prefetching is also necessary in order 
    # to return the id after an insert.
    #
    # Caveat: Operations involving LIMIT and OFFSET do not yet work!
    #
    # Maintainer: derrick.spell@gmail.com
    class OpenBaseAdapter < AbstractAdapter
      def adapter_name
        'OpenBase'
      end
      
      def native_database_types
        {
          :primary_key => "integer UNIQUE INDEX DEFAULT _rowid",
          :string      => { :name => "char", :limit => 4096 },
          :text        => { :name => "text" },
          :integer     => { :name => "integer" },
          :float       => { :name => "float" },
          :decimal     => { :name => "decimal" },
          :datetime    => { :name => "datetime" },
          :timestamp   => { :name => "timestamp" },
          :time        => { :name => "time" },
          :date        => { :name => "date" },
          :binary      => { :name => "object" },
          :boolean     => { :name => "boolean" }
        }
      end
      
      def supports_migrations?
        false
      end      
      
      def prefetch_primary_key?(table_name = nil)
        true
      end
      
      def default_sequence_name(table_name, primary_key) # :nodoc:
        "#{table_name} #{primary_key}"
      end
      
      def next_sequence_value(sequence_name)
        ary = sequence_name.split(' ')
        if (!ary[1]) then
          ary[0] =~ /(\w+)_nonstd_seq/
          ary[0] = $1
        end
        @connection.unique_row_id(ary[0], ary[1])
      end

      
      # QUOTING ==================================================
      
      def quote(value, column = nil)
        if value.kind_of?(String) && column && column.type == :binary
          "'#{@connection.insert_binary(value)}'"
        else
          super
        end
      end
      
      def quoted_true
        "1"
      end
      
      def quoted_false
        "0"
      end
      


      # DATABASE STATEMENTS ======================================

      def add_limit_offset!(sql, options) #:nodoc:
        if limit = options[:limit]
          unless offset = options[:offset]
            sql << " RETURN RESULTS #{limit}"
          else
            limit = limit + offset
            sql << " RETURN RESULTS #{offset} TO #{limit}"
          end
        end
      end
      
      def select_all(sql, name = nil) #:nodoc:
        select(sql, name)
      end

      def select_one(sql, name = nil) #:nodoc:
        add_limit_offset!(sql,{:limit => 1})
        results = select(sql, name)
        results.first if results
      end

      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        execute(sql, name)
        update_nulls_after_insert(sql, name, pk, id_value, sequence_name)
        id_value
      end
      
      def execute(sql, name = nil) #:nodoc:
        log(sql, name) { @connection.execute(sql) }
      end

      def update(sql, name = nil) #:nodoc:
        execute(sql, name).rows_affected
      end

      alias_method :delete, :update #:nodoc:
#=begin
      def begin_db_transaction #:nodoc:
        execute "START TRANSACTION"
      rescue Exception
        # Transactions aren't supported
      end

      def commit_db_transaction #:nodoc:
        execute "COMMIT"
      rescue Exception
        # Transactions aren't supported
      end

      def rollback_db_transaction #:nodoc:
        execute "ROLLBACK"
      rescue Exception
        # Transactions aren't supported
      end
#=end      

      # SCHEMA STATEMENTS ========================================

      # Return the list of all tables in the schema search path.
      def tables(name = nil) #:nodoc:
        tables = @connection.tables
        tables.reject! { |t| /\A_SYS_/ === t }
        tables
      end

      def columns(table_name, name = nil) #:nodoc:
        sql = "SELECT * FROM _sys_tables "
        sql << "WHERE tablename='#{table_name}' AND INDEXOF(fieldname,'_')<>0 "
        sql << "ORDER BY columnNumber"
        columns = []
        select_all(sql, name).each do |row|
          columns << OpenBaseColumn.new(row["fieldname"],
                                default_value(row["defaultvalue"]),
                                sql_type_name(row["typename"],row["length"]),
                                row["notnull"]
                                )
        end
        columns
      end

      def indexes(table_name, name = nil)#:nodoc:
        sql = "SELECT fieldname, notnull, searchindex, uniqueindex, clusteredindex FROM _sys_tables "
        sql << "WHERE tablename='#{table_name}' AND INDEXOF(fieldname,'_')<>0 "
        sql << "AND primarykey=0 "
        sql << "AND (searchindex=1 OR uniqueindex=1 OR clusteredindex=1) "
        sql << "ORDER BY columnNumber"
        indexes = []
        execute(sql, name).each do |row|
          indexes << IndexDefinition.new(table_name,index_name(row),row[3]==1,[row[0]])
        end
        indexes
      end


      private
        def select(sql, name = nil)
          sql = translate_sql(sql)
          results = execute(sql, name)

          date_cols = []
          col_names = []
          results.column_infos.each do |info|
            col_names << info.name
            date_cols << info.name if info.type == "date"
          end
          
          rows = []
          if ( results.rows_affected )
            results.each do |row|  # loop through result rows
              hashed_row = {}
              row.each_index do |index| 
                hashed_row["#{col_names[index]}"] = row[index] unless col_names[index] == "_rowid"
              end
              date_cols.each do |name|
                unless hashed_row["#{name}"].nil? or hashed_row["#{name}"].empty?
                  hashed_row["#{name}"] = Date.parse(hashed_row["#{name}"],false).to_s
                end
              end
              rows << hashed_row
            end
          end
          rows
        end
        
        def default_value(value)
          # Boolean type values
          return true if value =~ /true/
          return false if value =~ /false/
 
          # Date / Time magic values
          return Time.now.to_s if value =~ /^now\(\)/i
 
          # Empty strings should be set to null
          return nil if value.empty?
          
          # Otherwise return what we got from OpenBase
          # and hope for the best...
          return value
        end 
        
        def sql_type_name(type_name, length)
          return "#{type_name}(#{length})" if ( type_name =~ /char/ )
          type_name
        end
                
        def index_name(row = [])
          name = ""
          name << "UNIQUE " if row[3]
          name << "CLUSTERED " if row[4]
          name << "INDEX"
          name
        end
        
        def translate_sql(sql)
          
          # Change table.* to list of columns in table
          while (sql =~ /SELECT.*\s(\w+)\.\*/)
            table = $1
            cols = columns(table)
            if ( cols.size == 0 ) then
              # Maybe this is a table alias
              sql =~ /FROM(.+?)(?:LEFT|OUTER|JOIN|WHERE|GROUP|HAVING|ORDER|RETURN|$)/  
              $1 =~ /[\s|,](\w+)\s+#{table}[\s|,]/ # get the tablename for this alias
              cols = columns($1)
            end
            select_columns = []
            cols.each do |col|
              select_columns << table + '.' + col.name
            end
            sql.gsub!(table + '.*',select_columns.join(", ")) if select_columns
          end
   
          # Change JOIN clause to table list and WHERE condition
          while (sql =~ /JOIN/)
            sql =~ /((LEFT )?(OUTER )?JOIN (\w+) ON )(.+?)(?:LEFT|OUTER|JOIN|WHERE|GROUP|HAVING|ORDER|RETURN|$)/
            join_clause = $1 + $5
            is_outer_join = $3
            join_table = $4
            join_condition = $5
            join_condition.gsub!(/=/,"*") if is_outer_join
            if (sql =~ /WHERE/)
              sql.gsub!(/WHERE/,"WHERE (#{join_condition}) AND")
            else
              sql.gsub!(join_clause,"#{join_clause} WHERE #{join_condition}")
            end
            sql =~ /(FROM .+?)(?:LEFT|OUTER|JOIN|WHERE|$)/
            from_clause = $1
            sql.gsub!(from_clause,"#{from_clause}, #{join_table} ")
            sql.gsub!(join_clause,"")
          end
    
          # ORDER BY _rowid if no explicit ORDER BY
          # This will ensure that find(:first) returns the first inserted row
          if (sql !~ /(ORDER BY)|(GROUP BY)/)
            if (sql =~ /RETURN RESULTS/)
              sql.sub!(/RETURN RESULTS/,"ORDER BY _rowid RETURN RESULTS")
            else
              sql << " ORDER BY _rowid"
            end
          end
          
          sql
        end
        
        def update_nulls_after_insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil)
          sql =~ /INSERT INTO (\w+) \((.*)\) VALUES\s*\((.*)\)/m
          table = $1
          cols = $2
          values = $3
          cols = cols.split(',')
          values.gsub!(/'[^']*'/,"''")
          values.gsub!(/"[^"]*"/,"\"\"")
          values = values.split(',')
          update_cols = []
          values.each_index { |index| update_cols << cols[index] if values[index] =~ /\s*NULL\s*/ }
          update_sql = "UPDATE #{table} SET"
          update_cols.each { |col| update_sql << " #{col}=NULL," unless col.empty? }
          update_sql.chop!()
          update_sql << " WHERE #{pk}=#{quote(id_value)}"
          execute(update_sql, name + " NULL Correction") if update_cols.size > 0
        end
        
      end
  end
end
