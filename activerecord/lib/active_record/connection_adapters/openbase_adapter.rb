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

      if oba.raw_connection.connected?
        unless oba.tables.include?(ConnectionAdapters::OpenBaseAdapter::COLUMN_SUPPORT_TABLE)
          oba.execute(<<-SQL,"Creating OpenBase Column Support Table")
          CREATE TABLE #{ConnectionAdapters::OpenBaseAdapter::COLUMN_SUPPORT_TABLE} (name char, type char, precision int, scale int)
          SQL
        end
        oba.select_all("SELECT * FROM #{ConnectionAdapters::OpenBaseAdapter::COLUMN_SUPPORT_TABLE}").each do |col|
          ConnectionAdapters::OpenBaseAdapter::DECIMAL_COLUMNS.store(col["name"],[col["precision"],col["scale"]])
        end
      end

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

    # The OpenBase adapter works with the Ruby/Openbase driver by Derrick Spell,
    # provided with the distribution of OpenBase 10.0.6 and later
    # http://www.openbase.com
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
    #
    # Maintainer: derrick.spell@gmail.com
    class OpenBaseAdapter < AbstractAdapter
      DECIMAL_COLUMNS = {}
      COLUMN_SUPPORT_TABLE = "rails_openbase_column_support"
      def adapter_name
        'OpenBase'
      end

      def native_database_types
        {
          :primary_key => "integer NOT NULL UNIQUE INDEX DEFAULT _rowid",
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
        true
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
        elsif value.kind_of?(BigDecimal)
          return "'#{value.to_s}'"
        elsif column && column.type == :integer && column.sql_type =~ /decimal/
          return "'#{value.to_s}'"
        elsif [Float,Fixnum,Bignum].include?(value.class) && column && column.type == :string
          return "'#{value.to_s}'"
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
        return if options[:limit].nil?
        limit = options[:limit]
        offset = options[:offset]
        if limit == 0
          # Mess with the where clause to ensure we get no results
          if sql =~ /WHERE/i
            sql.sub!(/WHERE/i, 'WHERE 1 = 2 AND ')
          elsif sql =~ /ORDER\s+BY/i
            sql.sub!(/ORDER\s+BY/i, 'WHERE 1 = 2 ORDER BY')
          else
            sql << 'WHERE 1 = 2'
          end
        elsif offset.nil?
          sql << " RETURN RESULTS #{limit}"
        else
          sql << " RETURN RESULTS #{offset} TO #{limit + offset}"
        end
      end

      def insert(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        execute(sql, name)
        update_nulls_after_insert(sql, name, pk, id_value, sequence_name)
        id_value
      end

      def execute(sql, name = nil) #:nodoc:
        log(sql, name) { @connection.execute(sql) }
      end

      def direct_execute(sql, name = nil) #:nodoc:
        log(sql, name) { @connection.execute(sql) }
      end

      def update(sql, name = nil) #:nodoc:
        execute(sql, name).rows_affected
      end

      alias_method :delete, :update #:nodoc:

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


      # SCHEMA STATEMENTS ========================================
      # Return the list of all tables in the schema search path.
      def tables(name = nil) #:nodoc:
        tables = @connection.tables
        tables.reject! { |t| /\A_SYS_/ === t }
      end

      def columns(table_name, name = nil) #:nodoc:
        sql = "SELECT * FROM _sys_tables "
        sql << "WHERE tablename='#{table_name}' AND INDEXOF(fieldname,'_')<>0 "
        sql << "ORDER BY columnNumber"
        columns = []
        direct_execute(sql, name).each_hash do |row|
          columns << OpenBaseColumn.new(row["fieldname"],
                                default_value(row["defaultvalue"],row["typename"]),
                                sql_type_name(table_name,row["fieldname"],row["typename"],row["length"]),
                                row["notnull"] == 1 ? false : true)
        end
        columns
      end

      def column_names(table_name) #:nodoc:
        sql = "SELECT fieldname FROM _sys_tables "
        sql << "WHERE tablename='#{table_name}' AND INDEXOF(fieldname,'_')<>0 "
        sql << "ORDER BY columnNumber"
        names = direct_execute(sql).fetch_all
        names.flatten! || names
      end

      def indexes(table_name, name = nil)#:nodoc:
        sql = "SELECT fieldname, notnull, searchindex, uniqueindex, clusteredindex FROM _sys_tables "
        sql << "WHERE tablename='#{table_name}' AND INDEXOF(fieldname,'_')<>0 "
        sql << "AND primarykey=0 "
        sql << "AND (searchindex=1 OR uniqueindex=1 OR clusteredindex=1) "
        sql << "ORDER BY columnNumber"
        indexes = []
        execute(sql, name).each do |row|
          indexes << IndexDefinition.new(table_name,ob_index_name(row),row[3]==1,[row[0]])
        end
        indexes
      end

      def create_table(name, options = {}) #:nodoc:
        return_value = super

        # Get my own copy of TableDefinition so that i can detect decimal columns
        table_definition = TableDefinition.new(self)
        yield table_definition

        table_definition.columns.each do |col|
          if col.type == :decimal
            record_decimal(name, col.name, col.precision, col.scale)
          end
        end

        unless options[:id] == false
          primary_key = (options[:primary_key] || "id")
          direct_execute("CREATE PRIMARY KEY #{name} (#{primary_key})")
        end
        return_value
      end

      def rename_table(name, new_name)
        execute "RENAME #{name} #{new_name}"
      end

      def add_column(table_name, column_name, type, options = {})
        return_value = super(table_name, "COLUMN " + column_name.to_s, type, options)
        if type == :decimal
          record_decimal(table_name, column_name, options[:precision], options[:scale])
        end
      end

      def remove_column(table_name, column_name)
        execute "ALTER TABLE #{table_name} REMOVE COLUMN #{quote_column_name(column_name)}"
      end

      def rename_column(table_name, column_name, new_column_name)
        execute "ALTER TABLE #{table_name} RENAME #{quote_column_name(column_name)} TO #{quote_column_name(new_column_name)}"
      end

      def add_column_options!(sql, options) #:nodoc:
        sql << " NOT NULL" if options[:null] == false
        sql << " DEFAULT #{quote(options[:default], options[:column])}" if options_include_default?(options)
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        unless options_include_default?(options)
          options[:default] = select_one("SELECT * FROM _sys_tables WHERE tablename='#{table_name}' AND fieldname='#{column_name}'")["defaultvalue"]
        end

        change_column_sql = "ALTER TABLE #{table_name} ADD COLUMN #{column_name} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(change_column_sql, options)
        execute(change_column_sql)
      end

      def change_column_default(table_name, column_name, default)
        execute "ALTER TABLE #{table_name} COLUMN #{column_name} SET DEFAULT #{quote(default)}"
      end

      def add_index(table_name, column_name, options = {})
        if Hash === options # legacy support, since this param was a string
          index_type = options[:unique] ? "UNIQUE" : ""
        else
          index_type = options
        end
        execute "CREATE #{index_type} INDEX #{table_name} #{column_name}"
      end

      def remove_index(table_name, options = {})
        execute "DROP INDEX #{table_name} #{options === Hash ? options[:column] : options}"
      end

      def type_to_sql(type, limit = nil, precision = nil, scale = nil) #:nodoc:
        return super unless type.to_s == 'decimal'

        if (scale.to_i == 2)
          return 'money'
        elsif (scale.to_i == 0)
          return 'longlong'
        else
          return "char(#{precision.to_i + 1})"
        end
      end


      private
        def select(sql, name = nil)
          decimals = detect_decimals(sql) || []
          sql = add_order_by_rowid(sql)

          # OpenBase ignores the return results when there is a group by
          # so limit the result set that we return to rails if need be
          if (sql =~ /GROUP BY/i)
            sql.sub!(/RETURN RESULTS (\d+)( TO (\d+))?/i,"")

            results = execute(sql, name)
            if ($2)
              results.fetch_offset = $1.to_i
              results.fetch_limit = $3.to_i - $1.to_i
            elsif ($1)
              results.fetch_limit = $1.to_i
            end
          else
            results = execute(sql, name)
          end

          rows = []
          if ( results.rows_affected )
            results.each_hash do |row|  # loop through result rows
              row.delete("_rowid") if row.key?("_rowid")
              decimals.each do |name, precision, scale|
                row[name] = BigDecimal.new(row[name]) if row[name] === String
              end
              rows << row
            end
          end
          rows
        end

        def default_value(value,type=nil)
          return value if value.nil?

          # Boolean type values
          return true if value =~ /true/
          return false if value =~ /false/
          # Alternative boolean default declarations
          return true if (value == 1 && type == "boolean")
          return false if (value == 0 && type == "boolean")

          # Date / Time magic values
          return Time.now.to_s if value =~ /^now\(\)/i

          # Empty strings should be set to nil
          return nil if value.empty?

          # Otherwise return what we got from OpenBase
          # and hope for the best...
          # Take off the leading space and unquote
          value.lstrip!
          value = value[1,value.length-2] if value.first.eql?("'") && value.last.eql?("'")
          return nil if value.eql?("NULL")
          return value
        end

        def sql_type_name(table_name, col_name, type, length)
          full_name = table_name.to_s + "." + col_name.to_s
          if DECIMAL_COLUMNS.include?(full_name) && type != "longlong"
            return "decimal(#{DECIMAL_COLUMNS[full_name][0]},#{DECIMAL_COLUMNS[full_name][1]})"
          end
          return "#{type}(#{length})" if ( type =~ /char/ )
          type
        end

        def ob_index_name(row = [])
          name = ""
          name << "UNIQUE " if row[3]
          name << "CLUSTERED " if row[4]
          name << "INDEX"
          name
        end

        def detect_decimals(sql)
          # Detect any decimal columns that will need to be cast when fetched
          decimals = []
          sql =~ /SELECT\s+(.*)\s+FROM\s+(\w+)/i
          select_clause = $1
          main_table = $2
          if select_clause == "*"
            column_names(main_table).each do |col|
              full_name = main_table + "." + col
              if DECIMAL_COLUMNS.include?(full_name)
                decimals << [col,DECIMAL_COLUMNS[full_name][0].to_i,DECIMAL_COLUMNS[full_name][1].to_i]
              end
            end
          end
          return decimals
        end

        def add_order_by_rowid(sql)
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

        def record_decimal(table_name, column_name, precision, scale)
          full_name = table_name.to_s + "." + column_name.to_s
          DECIMAL_COLUMNS.store(full_name, [precision.to_i,scale.to_i])
          direct_execute("INSERT INTO #{COLUMN_SUPPORT_TABLE} (name,type,precision,scale) VALUES ('#{full_name}','decimal',#{precision.to_i},#{scale.to_i})")
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
          direct_execute(update_sql,"Null Correction") if update_cols.size > 0
        end
      end
  end
end
